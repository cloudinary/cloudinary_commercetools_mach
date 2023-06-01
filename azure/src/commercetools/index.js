const {SecretClient} = require("@azure/keyvault-secrets");
const {DefaultAzureCredential} = require("@azure/identity");
const axios = require('axios');

const getSecret = async (secretName) => {
    const vaultName = process.env['vaultName'];

    const url = `https://${vaultName}.vault.azure.net`;
    const credential = new DefaultAzureCredential();
    const client = new SecretClient(url, credential);

    const secret = await client.getSecret(secretName);

    return secret.value;
}

const getToken = async () => {
    const authUrl = process.env['authUrl'];
    const clientId = process.env['clientId'];
    const clientSecret = await getSecret('ct-client-secret');

    const bodyParams = new URLSearchParams();
    bodyParams.append("grant_type", 'client_credentials');

    const response = await axios.post(`${authUrl}/oauth/token`, bodyParams, {
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Authorization': 'Basic ' + (Buffer.from(clientId + ':' + clientSecret).toString('base64'))
        }
    });

    if (response.status !== 200) {
        console.log('getToken.error', {data: response.data});
        return;
    }

    return response.data.access_token;
}

const getProductTypeAttributes = async (id, token) => {
    const apiUrl = process.env["apiUrl"]
    const projectKey = process.env["projectKey"]

    const url = `${apiUrl}/${projectKey}/product-types/${id}`;

    const response = await axios.get(url, {
        headers: {
            authorization: `Bearer ${token}`,
        },
    });

    const productType = response.data
    const attributeNames = productType?.attributes?.map(x => x.name) ?? [];

    return attributeNames;
}

const getCloudinaryAsset = async (resourceType, publicId) => {
    const cloudName = process.env['cloud_name'];
    const cloudApiKey = process.env['cloud_api_key'];
    const cloudApiSecret = await getSecret('cloud-api-secret');

    const response = await axios.get(`https://api.cloudinary.com/v1_1/${cloudName}/resources/${resourceType}/upload/${publicId}`, {
        headers: {
            'Authorization': 'Basic ' + (Buffer.from(cloudApiKey + ':' + cloudApiSecret).toString('base64')),
            'X-cld-commercetools': 'azure-1.0.0',
        }
    })

    if (response.status === 200) {
        // console.log('getCloudinaryAsset.response', {data: response.data})
        return response.data
    }

    console.log('getCloudinaryAsset.Error', {data: response.data})
    return undefined
}

const searchProductBySku = async (sku, staged, token) => {
    const apiUrl = process.env["apiUrl"]
    const projectKey = process.env["projectKey"]

    const url = `${apiUrl}/${projectKey}/product-projections/search?staged=${staged}&filter=variants.sku:"${sku}"`
    const response = await axios.get(url, {
        headers: {
            'Authorization': `Bearer ${token}`
        }
    })

    if (response.status === 200) {
        const products = response.data
        return products.count === 1 ? products.results[0] : undefined
    }

    console.log('searchProductBySku.Error', {data: response.data})
    return undefined
}

const getProductBySku = async (sku, staged, token) => {
    /* Normal product search doesn't support looking by SKU
       Advanced search is only possible in the MerchantCenter
       Thus, we have to use product-projections to find the id, then fetch it through the normal API to make sure we have the latest version
       (projections have a noticeable delay when we expect multiple updates for the same product, e.g. multiple assets for the same SKU)
    */
    const productMatch = await searchProductBySku(sku, staged, token)
    if (productMatch) {
        const apiUrl = process.env["apiUrl"]
        const projectKey = process.env["projectKey"]
        const id = productMatch.id

        const url = `${apiUrl}/${projectKey}/products/${id}`;
        const response = await axios.get(url, {
            headers: {
                authorization: `Bearer ${token}`,
            },
        });

        if (response.status === 200) {
            const product = response.data;
            //const value = staged ? product.masterData.staged : product.masterData.current
            //We always pick the staged version, so that we do not accidentally duplicate assets that were already staged but not yet published
            const value = product.masterData.staged

            return {
                ...value,
                id: product.id,
                version: product.version,
                productType: product.productType,
                published: product.masterData.published,
                hasStagedChanges: product.masterData.hasStagedChanges
            }
        }

        console.log('getProductBySku.Error', {data: response.data});
    }

    return undefined;
}

const updateProduct = async (product, actions, token, context) => {
    const apiUrl = process.env["apiUrl"]
    const projectKey = process.env["projectKey"]

    const url = `${apiUrl}/${projectKey}/products/${product.id}`;

    const response = await axios.post(url, JSON.stringify({
        version: product.version,
        actions,
    }), {
        headers: {
            authorization: `Bearer ${token}`,
        }
    })

    // If this throws an error 409, that's okay. We're trying to update the same product in parallel, which fails.
    // But the servicebus will pick it up on a second attempt
    const updatedProduct = response.data;
    context.log('updateProduct', {actions: JSON.stringify(actions)})

    return updatedProduct;
}

const getVariantBySku = (product, sku) => {
    return product.masterVariant.sku === sku
        ? product.masterVariant
        : product.variants.find(x => x.sku === sku);
}

const getAssetActions = (product, sku, metadata, assetName, assetDescription, publicId, resourceType, format, tags) => {
    // Check if assets exists
    const assets = getVariantBySku(product, sku).assets ?? [];
    const existingAsset = assets.find(x => x.sources[0].uri === publicId);

    const ctCustomTypeKey = process.env['ct_asset_type_key'];
    const ctSortProperty = process.env['ct_property_sort'];
    const cldSortProperty = process.env['property_sort'];

    const sortOrder = metadata[cldSortProperty];

    // Add if not exists
    if (!existingAsset) {
        const actions = [
            {
                action: 'addAsset',
                sku,
                asset: {
                    name: {
                        'en-US': assetName ?? '',
                    },
                    description: {
                        'en-US': assetDescription ?? '',
                    },
                    sources: [
                        {
                            uri: publicId,
                            contentType: resourceType === 'video' ? `video/${format}` : `image/${format}`,
                        }
                    ],
                    tags: tags ?? [],
                },
            }
        ];

        if (ctCustomTypeKey && sortOrder) {
            actions[0].asset.custom = {
                type: {
                    key: ctCustomTypeKey,
                },
                fields: {
                    [ctSortProperty]: sortOrder,
                },
            }
        }

        return actions
    } else {
        // Update name and description
        const actions = [
            {
                action: 'changeAssetName',
                sku,
                assetId: existingAsset.id,
                name: {
                    'en-US': assetName ?? '',
                }
            },
            {
                action: 'setAssetDescription',
                sku,
                assetId: existingAsset.id,
                description: {
                    'en-US': assetDescription ?? '',
                }
            }
        ];

        if (ctCustomTypeKey && sortOrder) {
            actions.push({
                action: 'setAssetCustomType',
                sku,
                assetId: existingAsset.id,
                type: {
                    key: ctCustomTypeKey,
                },
                fields: {
                    [ctSortProperty]: sortOrder,
                },
            });
        }

        return actions;
    }
}

const deleteAssetAction = (product, sku, publicId) => {
    // Check if assets exists
    const assets = getVariantBySku(product, sku).assets ?? [];
    const existingAsset = assets.find(x => x.sources[0].uri === publicId);

    // Add if not exists
    if (!existingAsset) {
        return undefined;
    }

    return {
        action: 'removeAsset',
        sku,
        assetId: existingAsset.id,
    };
}

const getThumbnailAction = (product, sku, assetName, resourceType, secureUrl) => {
    const transformation = resourceType === 'image' ? 'c_thumb,w_400,h_400' : 'c_thumb,w_400,h_400/f_jpg';
    const thumbnailUrl = secureUrl.replace('upload/', `upload/${transformation}/`);

    // Check if assets exists
    const images = getVariantBySku(product, sku).images ?? [];
    const existingImage = images.find(x => x.url === thumbnailUrl);

    // Add if not exists
    if (existingImage) {
        return undefined;
    }

    return {
        action: 'addExternalImage',
        sku,
        image: {
            url: thumbnailUrl,
            label: assetName,
            dimensions: {
                w: 400,
                h: 400,
            }
        }
    };
}

const deleteThumbnailAction = (product, sku, resourceType, secureUrl) => {
    const transformation = resourceType === 'image' ? 'c_thumb,w_400,h_400' : 'c_thumb,w_400,h_400/f_jpg'
    const thumbnailUrl = secureUrl.replace('upload/', `upload/${transformation}/`)

    // Check if assets exists
    const images = getVariantBySku(product, sku).images ?? [];
    const existingImage = images.find(x => x.url === thumbnailUrl);

    // Add if not exists
    if (!existingImage) {
        return undefined;
    }

    return {
        action: 'removeImage',
        sku,
        imageUrl: thumbnailUrl,
    };
}

const getAttributeActions = async (product, sku, metadata, token) => {
    const actions = [];

    const attributes = await getProductTypeAttributes(product.productType.id, token)
    attributes.forEach(attributeName => {
        const existingValue = getVariantBySku(product, sku).attributes.find(x => x.name === attributeName)?.value;

        /*  Expected format
            ---------------
            metadata: {
                property1: <string or array>,
                property2: <string or array>,
            }
        */
        let newValue = metadata[attributeName];

        /*  Falling back to asset-format in MediaFlows
            ------------------------------------------
            metadata: [
                {
                    id: "property1",
                    label: ...
                    type: ...
                    value: <string or array>
                    isMandatory: ...
                    ...
                }
            ]
        */
        if (!newValue && Array.isArray(metadata)) {
            const attribute = metadata.find(x => x.id === attributeName);
            if (attribute) {
                if (attribute.type === 'set') {
                    newValue = attribute.value.map(x => x.id);
                } else {
                    newValue = attribute.value;
                }
            }
        }

        if (newValue && (!existingValue || existingValue !== newValue)) {
            //console.log(`Updating attribute ${attributeName}`)
            actions.push({
                action: 'setAttribute',
                sku,
                name: attributeName,
                value: newValue
            })
        }
    });

    return actions;
}

const getAssetFromNotification = async (resource_type, publicId) => {
    // Get asset information
    const assetData = await getCloudinaryAsset(resource_type, publicId);
    if (!assetData) {
        return undefined;
    }

    const {secure_url, metadata, format, tags, context} = assetData;
    const property_sku = process.env['property_sku'];
    const sku = metadata[property_sku];
    const property_publish = process.env['property_publish'];
    const publish = metadata[property_publish];
    const name = context?.custom?.caption;
    const description = context?.custom?.alt;

    return {
        publicId,
        sku,
        publish,
        name,
        description,
        secure_url,
        metadata,
        resource_type,
        format,
        tags
    };
}

const processNewAsset = async (asset, flag, context) => {
    const {
        publicId,
        sku,
        name,
        description,
        secure_url,
        metadata,
        resource_type,
        format,
        tags
    } = asset;

    const token = await getToken();
    const staged = (flag === 'cld_ct_draft');

    const product = await getProductBySku(sku, staged, token);
    if (!product) {
        return {
            status: 404,
            body: {
                sku,
                error: 'Product not found'
            }
        };
    }

    let actions = [];
    if (flag === 'cld_ct_unpublish') {
        // Gather remove actions
        const assetAction = deleteAssetAction(product, sku, publicId);
        if (assetAction) {
            actions.push(assetAction);
        }

        const thumbnailAction = deleteThumbnailAction(product, sku, resource_type, secure_url);
        if (thumbnailAction) {
            actions.push(thumbnailAction);
        }

        if (actions.length > 0) {
            actions.push({
                action: 'publish',
            });
        }
    } else {
        // Gather update actions
        actions = await getAttributeActions(product, sku, metadata, token);
        const assetActions = getAssetActions(product, sku, metadata, name, description, publicId, resource_type, format, tags);
        if (assetActions.length > 0) {
            assetActions.forEach(assetAction => {
                actions.push(assetAction);
            })
        }

        const thumbnailAction = getThumbnailAction(product, sku, name, resource_type, secure_url);
        if (thumbnailAction) {
            actions.push(thumbnailAction);
        }

        if (!staged && (actions.length > 0 || product.hasStagedChanges)) {
            actions.push({
                action: 'publish',
            });
        }
    }

    if (actions.length > 0) {
        await updateProduct(product, actions, token, context);
    }

    return {
        status: 200,
        body: {
            sku,
            actions,
        }
    }
}

const processOldAsset = async (asset, sku, flag, context) => {
    const {
        publicId,
        secure_url,
        resource_type,
    } = asset;

    const token = await getToken();
    const staged = (flag === 'cld_ct_draft');

    const product = await getProductBySku(sku, staged, token);
    if (!product) {
        return {
            status: 404,
            body: {
                sku,
                error: 'Product not found'
            }
        };
    }

    let actions = [];

    // Gather remove actions
    const assetAction = deleteAssetAction(product, sku, publicId);
    if (assetAction) {
        actions.push(assetAction);
    }

    const thumbnailAction = deleteThumbnailAction(product, sku, resource_type, secure_url);
    if (thumbnailAction) {
        actions.push(thumbnailAction);
    }

    if (actions.length > 0) {
        actions.push({
            action: 'publish',
        });
    }


    if (actions.length > 0) {
        await updateProduct(product, actions, token, context);
    }

    return {
        status: 200,
        body: {
            sku,
            actions,
        }
    };
}

exports.processWebhookNotification = async (body, context) => {
    const resource = body.resources[0]

    // Identify the asset
    const {resource_type, publicId, previous_metadata, new_metadata} = body.resources[0];

    const asset = await getAssetFromNotification(resource_type, publicId);
    if (!asset) {
        return {
            status: 404,
            body: {
                error: 'Asset not found'
            }
        };
    }

    const flag = asset.publish;

    if (!flag) {
        return {
            status: 404,
            body: {
                error: 'Publish flag not found'
            }
        };
    }

    const result = {
        status: 200,
        body: {
            sku: asset.sku,
        }
    }

    // Remove asset/thumbnails from the previous product
    const oldSku = previous_metadata ? previous_metadata[process.env['property_sku']] : '';
    const newSku = asset.sku;
    if (oldSku && newSku && oldSku !== newSku) {
        result.body.oldAsset = await processOldAsset(asset, oldSku, flag, context);
    }

    // Add assets/thumbnails to the current product
    result.body.newAsset = await processNewAsset(asset, flag, context);

    return result;
}

exports.processAddAsset = async (request) => {
    const {
        sku,
        token,
        staged = false,
        displayName = '',
        publicId,
        secureUrl,
        resourceType,
        format
    } = await request.json();

    const errors = []
    if (!sku) {
        errors.push('sku missing');
    }
    if (!token) {
        errors.push('token missing');
    }
    if (!publicId) {
        errors.push('publicId missing');
    }
    if (!secureUrl) {
        errors.push('secureUrl missing');
    }
    if (!resourceType) {
        errors.push('resourceType missing');
    }
    if (!format) {
        errors.push('format missing');
    }

    if (errors.length > 0) {
        return {
            status: 400,
            body: {errors},
        };
    }

    try {
        const product = await getProductBySku(sku, staged, token);
        if (!product) {
            return {
                status: 404,
                body: {
                    sku,
                    error: 'Product not found'
                }
            };
        }

        const actions = []
        const assetAction = getAssetActions(product, sku, displayName, publicId, resourceType, format, secureUrl);
        if (assetAction) {
            actions.push(assetAction);
        }

        if (!staged && actions.length > 0) {
            console.log('Publishing changes ...');
            actions.push({
                action: 'publish',
            });
        }

        let updatedProduct
        if (actions.length > 0) {
            updatedProduct = await updateProduct(product, actions, token);
        }

        return {
            status: 200,
            body: {
                sku,
                actions,
            }
        }
    } catch (err) {
        return {
            status: 400,
            body: {
                error: err.toString(),
                message: err.name === 'AxiosError' ? "Probable cause: invalid token" : undefined
            }
        }
    }
}

exports.processDeleteAsset = async (request) => {
    const {sku, token, staged = false, publicId} = await request.json();

    const errors = []
    if (!sku) {
        errors.push('sku missing');
    }
    if (!token) {
        errors.push('token missing');
    }
    if (!publicId) {
        errors.push('publicId missing');
    }

    if (errors.length > 0) {
        return {
            status: 400,
            body: {errors},
        };
    }

    try {
        const product = await getProductBySku(sku, staged, token);
        if (!product) {
            return {
                status: 404,
                body: {
                    sku,
                    error: 'Product not found'
                }
            };
        }

        const actions = []
        const assetAction = deleteAssetAction(product, sku, publicId);
        if (assetAction) {
            actions.push(assetAction);
        }

        if (!staged && actions.length > 0) {
            console.log('Publishing changes ...');
            actions.push({
                action: 'publish',
            });
        }

        let updatedProduct
        if (actions.length > 0) {
            updatedProduct = await updateProduct(product, actions, token);
        }

        return {
            body: {
                sku,
                actions
            }
        }
    } catch (err) {
        return {
            status: 400,
            body: {
                error: err.toString(),
                message: err.name === 'AxiosError' ? "Probable cause: invalid token" : undefined
            }
        }
    }
}

exports.processAddThumbnail = async (request) => {
    const {sku, token, staged = false, displayName = '', secureUrl, resourceType} = await request.json();

    const errors = [];
    if (!sku) {
        errors.push('sku missing');
    }
    if (!token) {
        errors.push('token missing');
    }
    if (!secureUrl) {
        errors.push('secureUrl missing');
    }
    if (!resourceType) {
        errors.push('resourceType missing');
    }

    if (errors.length > 0) {
        return {
            status: 400,
            body: {errors},
        };
    }

    try {
        const product = await getProductBySku(sku, staged, token);
        if (!product) {
            return {
                success: false,
                sku,
                error: 'Product not found'
            };
        }

        const actions = []
        const thumbnailAction = getThumbnailAction(product, sku, displayName, resourceType, secureUrl);
        if (thumbnailAction) {
            actions.push(thumbnailAction);
        }

        if (!staged && actions.length > 0) {
            console.log('Publishing changes ...');
            actions.push({
                action: 'publish',
            });
        }

        if (actions.length > 0) {
            await updateProduct(product, actions, token);
        }

        return {
            body: {
                sku,
                actions
            }
        }
    } catch (err) {
        return {
            status: 400,
            body: {
                error: err.toString(),
                message: err.name === 'AxiosError' ? "Probable cause: invalid token" : undefined
            }
        }
    }
}

exports.processDeleteThumbnail = async (request) => {
    const {sku, token, staged = false, secureUrl, resourceType} = await request.json();

    const errors = [];
    if (!sku) {
        errors.push('sku missing');
    }
    if (!token) {
        errors.push('token missing');
    }
    if (!secureUrl) {
        errors.push('secureUrl missing');
    }
    if (!resourceType) {
        errors.push('resourceType missing');
    }

    if (errors.length > 0) {
        return {
            status: 400,
            body: {errors},
        };
    }

    try {
        const product = await getProductBySku(sku, staged, token);
        if (!product) {
            return {
                status: 404,
                body: {
                    sku,
                    error: 'Product not found'
                }
            };
        }

        const actions = []
        const assetAction = deleteThumbnailAction(product, sku, resourceType, secureUrl);
        if (assetAction) {
            actions.push(assetAction);
        }

        if (!staged && actions.length > 0) {
            console.log('Publishing changes ...');
            actions.push({
                action: 'publish',
            });
        }

        let updatedProduct
        if (actions.length > 0) {
            updatedProduct = await updateProduct(product, actions, token);
        }

        return {
            body: {
                sku,
                actions
            }
        }
    } catch (err) {
        console.error('processDeleteThumbnail', {err});
        return {
            status: 400,
            body: {
                error: err.toString(),
                message: err.name === 'AxiosError' ? "Probable cause: invalid token" : undefined
            }
        }
    }
}

exports.processSetProperties = async (request) => {
    const {sku, token, staged = false, metadata} = await request.json();

    const errors = []
    if (!sku) {
        errors.push('sku missing');
    }
    if (!token) {
        errors.push('token missing');
    }
    if (!metadata) {
        errors.push('metadata missing');
    }

    if (errors.length > 0) {
        return {
            status: 400,
            body: {errors},
        };
    }

    try {
        const product = await getProductBySku(sku, staged, token);
        if (!product) {
            return {
                status: 404,
                body: {
                    sku,
                    error: 'Product not found'
                }
            };
        }

        const actions = await getAttributeActions(product, sku, metadata, token);

        if (!staged && actions.length > 0) {
            console.log('Publishing changes ...');
            actions.push({
                action: 'publish',
            });
        }

        if (actions.length > 0) {
            await updateProduct(product, actions, token);
        }

        return {
            body: {
                sku,
                actions
            }
        }
    } catch (err) {
        return {
            status: 400,
            body: {
                error: err.toString(),
                message: err.name === 'AxiosError' ? "Probable cause: invalid token" : undefined
            }
        }
    }
}
