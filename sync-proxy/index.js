const express = require('express');
const cors = require('cors');
const axios = require('axios');
const admin = require('firebase-admin');


// Initialize Firebase Admin (uses Application Default Credentials on Cloud Run)
admin.initializeApp({
  storageBucket: 'storeordering-10125.firebasestorage.app',
});

const app = express();
app.use(cors());
app.use(express.json({ limit: '50mb' }));

// Shopify credentials — same store as the orders proxy
const SHOPIFY_SHOP = process.env.SHOPIFY_SHOP || 'apnirootsgrocery.myshopify.com';
const SHOPIFY_TOKEN = process.env.SHOPIFY_TOKEN || 'xx';
const PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : 3001;
const API_VERSION = '2024-01';

// ─── Health check ───────────────────────────────────────────
app.get('/', (req, res) => {
  res.json({ status: 'ok', service: 'sync-proxy' });
});

// ─── Search product by SKU / barcode ────────────────────────
// GET /product-by-sku?sku=068656017070
app.get('/product-by-sku', async (req, res) => {
  const sku = (req.query.sku || '').trim();
  if (!sku) {
    return res.status(400).json({ error: 'Missing ?sku= parameter' });
  }

  console.log(`[product-by-sku] Searching for SKU: ${sku}`);

  try {
    // Strategy 1: Search by barcode (most accurate for UPC barcodes)
    let product = await searchProducts(`barcode:${sku}`);
    if (product) {
      console.log(`[product-by-sku] Found by barcode: ${product.title}`);
      return res.json({ found: true, match: 'barcode', product });
    }

    // Strategy 2: Search by variant SKU field
    product = await searchProducts(`sku:${sku}`);
    if (product) {
      console.log(`[product-by-sku] Found by sku: ${product.title}`);
      return res.json({ found: true, match: 'sku', product });
    }

    // Strategy 3: General title/body search (loose match)
    product = await searchProducts(sku);
    if (product) {
      console.log(`[product-by-sku] Found by general search: ${product.title}`);
      return res.json({ found: true, match: 'loose', product });
    }

    console.log(`[product-by-sku] Not found: ${sku}`);
    return res.json({ found: false, product: null });
  } catch (err) {
    console.error('[product-by-sku] Error:', err.message);
    const status = err.response?.status || 500;
    const data = err.response?.data || { error: err.message };
    return res.status(status).json(data);
  }
});

// ─── Helper: search Shopify Admin API for products ──────────
async function searchProducts(query) {
  const url = `https://${SHOPIFY_SHOP}/admin/api/${API_VERSION}/products.json`;
  const response = await axios.get(url, {
    params: {
      limit: 5,
      fields: 'id,title,status,variants,image,handle',
      // Note: the "query" param works for products.json search
    },
    headers: {
      'X-Shopify-Access-Token': SHOPIFY_TOKEN,
      'Content-Type': 'application/json',
    },
  });

  // The REST products.json doesn't support a `query` param directly.
  // We need to use the GraphQL API for proper search.
  // Let's use GraphQL instead.
  return await searchProductsGraphQL(query);
}

// ─── GraphQL product search (supports barcode:, sku:, etc.) ─
async function searchProductsGraphQL(query) {
  const url = `https://${SHOPIFY_SHOP}/admin/api/${API_VERSION}/graphql.json`;

  const gql = `
    {
      products(first: 5, query: "${query.replace(/"/g, '\\"')}") {
        edges {
          node {
            id
            title
            status
            handle
            tags
            featuredImage {
              url
            }
            variants(first: 5) {
              edges {
                node {
                  sku
                  barcode
                  price
                  taxable
                  inventoryQuantity
                }
              }
            }
          }
        }
      }
    }
  `;

  const response = await axios.post(url, { query: gql }, {
    headers: {
      'X-Shopify-Access-Token': SHOPIFY_TOKEN,
      'Content-Type': 'application/json',
    },
  });

  const edges = response.data?.data?.products?.edges;
  if (!edges || edges.length === 0) return null;

  const node = edges[0].node;
  const variants = node.variants?.edges?.map(e => e.node) || [];
  const firstVariant = variants[0] || {};

  return {
    title: node.title,
    status: node.status,
    handle: node.handle,
    shopifyId: node.id,
    tags: node.tags || [],
    image: node.featuredImage?.url || '',
    sku: firstVariant.sku || '',
    barcode: firstVariant.barcode || '',
    price: firstVariant.price || '',
    taxable: firstVariant.taxable ?? true,
    inventoryQty: firstVariant.inventoryQuantity ?? 0,
    url: `https://${SHOPIFY_SHOP.replace('.myshopify.com', '')}.myshopify.com/admin/products/${node.id?.split('/')?.pop() || ''}`,
    publicUrl: `https://apniroots.com/products/${node.handle}`,
  };
}

// ─── Create a NEW product on Shopify ────────────────────────
// POST /create-product
// Body: { title, sku, barcode, price, description, vendor, productType, imageUrl, tags, taxable }
app.post('/create-product', async (req, res) => {
  const { title, sku, barcode, price, description, vendor, productType, imageUrl, imageBase64, tags, taxable } = req.body;

  if (!title) {
    return res.status(400).json({ error: 'Missing required field: title' });
  }

  console.log(`[create-product] Creating: ${title} (SKU: ${sku || 'none'})`);

  try {
    // Build the product payload for REST API
    const productPayload = {
      product: {
        title,
        body_html: description || '',
        vendor: vendor || '',
        product_type: productType || '',
        tags: tags || '',
        status: 'active', // Create as active — ready to sell
        variants: [
          {
            sku: sku || '',
            barcode: barcode || '',
            price: price || '0.00',
            taxable: taxable !== undefined ? taxable : true,
            inventory_management: null,
            inventory_policy: 'deny',
          },
        ],
      },
    };

    // Add image — prefer base64 (direct from phone), fall back to URL
    if (imageBase64) {
      productPayload.product.images = [{ attachment: imageBase64 }];
      console.log(`[create-product] Using base64 image (${imageBase64.length} chars)`);
    } else if (imageUrl) {
      productPayload.product.images = [{ src: imageUrl }];
    }

    const url = `https://${SHOPIFY_SHOP}/admin/api/${API_VERSION}/products.json`;
    const response = await axios.post(url, productPayload, {
      headers: {
        'X-Shopify-Access-Token': SHOPIFY_TOKEN,
        'Content-Type': 'application/json',
      },
    });

    const created = response.data.product;
    const firstVariant = created.variants?.[0] || {};

    console.log(`[create-product] Created: ${created.title} (ID: ${created.id})`);

    return res.json({
      success: true,
      action: 'created',
      product: {
        shopifyId: created.id,
        title: created.title,
        status: created.status,
        handle: created.handle,
        sku: firstVariant.sku || '',
        barcode: firstVariant.barcode || '',
        price: firstVariant.price || '',
        variantId: firstVariant.id,
        image: created.images?.[0]?.src || '',
        url: `https://${SHOPIFY_SHOP}/admin/products/${created.id}`,
        publicUrl: `https://apniroots.com/products/${created.handle}`,
      },
    });
  } catch (err) {
    console.error('[create-product] Error:', err.response?.data || err.message);
    const status = err.response?.status || 500;
    return res.status(status).json({ error: err.response?.data || err.message });
  }
});

// ─── Update an EXISTING product on Shopify ──────────────────
// PUT /update-product
// Body: { shopifyProductId, title, sku, barcode, price, description, vendor, productType, imageUrl, tags, status, taxable }
app.put('/update-product', async (req, res) => {
  const { shopifyProductId, title, sku, barcode, price, description, vendor, productType, imageUrl, imageBase64, tags, status, variantId, taxable } = req.body;

  if (!shopifyProductId) {
    return res.status(400).json({ error: 'Missing required field: shopifyProductId' });
  }

  console.log(`[update-product] Updating product ID: ${shopifyProductId}`);

  try {
    // Build update payload — only include fields that are provided
    const productUpdate = {};
    if (title !== undefined) productUpdate.title = title;
    if (description !== undefined) productUpdate.body_html = description;
    if (vendor !== undefined) productUpdate.vendor = vendor;
    if (productType !== undefined) productUpdate.product_type = productType;
    if (tags !== undefined) productUpdate.tags = tags;
    if (status !== undefined) productUpdate.status = status;

    // Update variant (price, sku, barcode, taxable) if provided
    if (variantId && (sku !== undefined || barcode !== undefined || price !== undefined || taxable !== undefined)) {
      productUpdate.variants = [{
        id: variantId,
        ...(sku !== undefined && { sku }),
        ...(barcode !== undefined && { barcode }),
        ...(price !== undefined && { price }),
        ...(taxable !== undefined && { taxable }),
      }];
    }

    // Add image — prefer base64 (direct from phone), fall back to URL
    if (imageBase64) {
      productUpdate.images = [{ attachment: imageBase64 }];
      console.log(`[update-product] Using base64 image (${imageBase64.length} chars)`);
    } else if (imageUrl) {
      productUpdate.images = [{ src: imageUrl }];
    }

    const url = `https://${SHOPIFY_SHOP}/admin/api/${API_VERSION}/products/${shopifyProductId}.json`;
    const response = await axios.put(url, { product: productUpdate }, {
      headers: {
        'X-Shopify-Access-Token': SHOPIFY_TOKEN,
        'Content-Type': 'application/json',
      },
    });

    const updated = response.data.product;
    const firstVariant = updated.variants?.[0] || {};

    console.log(`[update-product] Updated: ${updated.title}`);

    return res.json({
      success: true,
      action: 'updated',
      product: {
        shopifyId: updated.id,
        title: updated.title,
        status: updated.status,
        handle: updated.handle,
        sku: firstVariant.sku || '',
        barcode: firstVariant.barcode || '',
        price: firstVariant.price || '',
        variantId: firstVariant.id,
        image: updated.images?.[0]?.src || '',
        url: `https://${SHOPIFY_SHOP}/admin/products/${updated.id}`,
        publicUrl: `https://apniroots.com/products/${updated.handle}`,
      },
    });
  } catch (err) {
    console.error('[update-product] Error:', err.response?.data || err.message);
    const status = err.response?.status || 500;
    return res.status(status).json({ error: err.response?.data || err.message });
  }
});

// ─── Upsert: Create or Update based on SKU lookup ───────────
// POST /sync-product
// Body: { title, sku, barcode, price, description, vendor, productType, imageUrl, imageBase64, tags, taxable }
app.post('/sync-product', async (req, res) => {
  const { title, sku, barcode, price, description, vendor, productType, imageUrl, imageBase64, tags, taxable } = req.body;

  if (!sku && !barcode) {
    return res.status(400).json({ error: 'Need at least sku or barcode to sync' });
  }

  const lookupKey = sku || barcode;
  console.log(`[sync-product] Syncing: ${title || lookupKey}`);

  try {
    // First check if the product already exists on Shopify
    let existing = await searchProductsGraphQL(`barcode:${lookupKey}`);
    if (!existing && sku) existing = await searchProductsGraphQL(`sku:${sku}`);

    if (existing) {
      // Product exists — update it
      const shopifyNumericId = existing.shopifyId?.split('/')?.pop();
      console.log(`[sync-product] Found existing product (${shopifyNumericId}), updating...`);

      // Get variant ID for update
      const detailUrl = `https://${SHOPIFY_SHOP}/admin/api/${API_VERSION}/products/${shopifyNumericId}.json?fields=id,variants`;
      const detailResp = await axios.get(detailUrl, {
        headers: { 'X-Shopify-Access-Token': SHOPIFY_TOKEN },
      });
      const variantId = detailResp.data.product?.variants?.[0]?.id;

      // Forward to update endpoint
      req.body.shopifyProductId = shopifyNumericId;
      req.body.variantId = variantId;

      const productUpdate = {
        title, vendor, product_type: productType, tags,
      };
      if (description !== undefined) productUpdate.body_html = description;

      const updatePayload = { product: { ...productUpdate } };
      if (variantId) {
        updatePayload.product.variants = [{
          id: variantId,
          sku: sku || '',
          barcode: barcode || '',
          price: price || '0.00',
          ...(taxable !== undefined && { taxable }),
        }];
      }
      if (imageBase64) {
        updatePayload.product.images = [{ attachment: imageBase64 }];
        console.log(`[sync-product] Using base64 image for update (${imageBase64.length} chars)`);
      } else if (imageUrl) {
        updatePayload.product.images = [{ src: imageUrl }];
      }

      const updateUrl = `https://${SHOPIFY_SHOP}/admin/api/${API_VERSION}/products/${shopifyNumericId}.json`;
      const updateResp = await axios.put(updateUrl, updatePayload, {
        headers: {
          'X-Shopify-Access-Token': SHOPIFY_TOKEN,
          'Content-Type': 'application/json',
        },
      });

      const updated = updateResp.data.product;
      const fv = updated.variants?.[0] || {};
      return res.json({
        success: true,
        action: 'updated',
        product: {
          shopifyId: updated.id,
          title: updated.title,
          status: updated.status,
          handle: updated.handle,
          sku: fv.sku || '',
          barcode: fv.barcode || '',
          price: fv.price || '',
          variantId: fv.id,
          image: updated.images?.[0]?.src || '',
          url: `https://${SHOPIFY_SHOP}/admin/products/${updated.id}`,
          publicUrl: `https://apniroots.com/products/${updated.handle}`,
        },
      });
    } else {
      // Product doesn't exist — create it
      console.log(`[sync-product] Not found on Shopify, creating new...`);

      const productPayload = {
        product: {
          title: title || lookupKey,
          body_html: description || '',
          vendor: vendor || '',
          product_type: productType || '',
          tags: tags || '',
          status: 'active',
          variants: [{
            sku: sku || '',
            barcode: barcode || '',
            price: price || '0.00',
            taxable: taxable !== undefined ? taxable : true,
            inventory_management: null,
          }],
        },
      };
      if (imageBase64) {
        productPayload.product.images = [{ attachment: imageBase64 }];
        console.log(`[sync-product] Using base64 image for create (${imageBase64.length} chars)`);
      } else if (imageUrl) {
        productPayload.product.images = [{ src: imageUrl }];
      }

      const createUrl = `https://${SHOPIFY_SHOP}/admin/api/${API_VERSION}/products.json`;
      const createResp = await axios.post(createUrl, productPayload, {
        headers: {
          'X-Shopify-Access-Token': SHOPIFY_TOKEN,
          'Content-Type': 'application/json',
        },
      });

      const created = createResp.data.product;
      const fv = created.variants?.[0] || {};
      return res.json({
        success: true,
        action: 'created',
        product: {
          shopifyId: created.id,
          title: created.title,
          status: created.status,
          handle: created.handle,
          sku: fv.sku || '',
          barcode: fv.barcode || '',
          price: fv.price || '',
          variantId: fv.id,
          image: created.images?.[0]?.src || '',
          url: `https://${SHOPIFY_SHOP}/admin/products/${created.id}`,
          publicUrl: `https://apniroots.com/products/${created.handle}`,
        },
      });
    }
  } catch (err) {
    console.error('[sync-product] Error:', err.response?.data || err.message);
    const status = err.response?.status || 500;
    return res.status(status).json({ error: err.response?.data || err.message });
  }
});

// ─── Generate Pennylane POS import file ─────────────────────
// POST /generate-pos-import
// Body: { products: [{ sku, name, price, cost, department, vendor, reorderLevel, reorderQty, taxCode }] }
//
// Penny Lane updateproduct.PLU — FORMAT batch style:
//   FORMAT:183,1,[1],<fieldcode>[2]    ← header (NO comma before [2])
//   <sku>,<value>                      ← one line per product
//
//   Field codes:
//     2  = PLU Number
//     3  = Description (30 chars max, UPPERCASE)
//     4  = Department (1-200, 0=delete)
//     5  = Price * 100
//     6  = Cost * 100
//     a  = Tax code (1-10)
//     p  = Vendor code
//     q  = Re-order level
//     r  = Suggested Re-order Qty
app.post('/generate-pos-import', async (req, res) => {
  const { products, format } = req.body;
  if (!products || !Array.isArray(products) || products.length === 0) {
    return res.status(400).json({ error: 'Missing products array' });
  }

  console.log(`[generate-pos-import] Generating for ${products.length} products (format: ${format || 'pennylane'})`);

  // If CSV format requested (legacy), return simple CSV
  if (format === 'csv') {
    const header = 'PLU_NUM,DESC,DEPT,DEPTNAME,PRICE,COST,VENDNAME,REORD_LVL,REORD_QTY';
    const rows = products.map(p => {
      const esc = (v) => {
        const s = String(v || '');
        return s.includes(',') || s.includes('"') ? `"${s.replace(/"/g, '""')}"` : s;
      };
      return [
        esc(p.sku), esc(p.name), esc(p.department || ''), esc(p.departmentName || ''),
        esc(p.price || '0'), esc(p.cost || '0'), esc(p.vendor || ''),
        esc(p.reorderLevel || '0'), esc(p.reorderQty || '0'),
      ].join(',');
    });
    const csv = [header, ...rows].join('\n');
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="NewCodes_import.csv"');
    return res.send(csv);
  }

  // Default: Penny Lane NewCodes.txt FORMAT batch style
  // Confirmed working format: FORMAT:183,1,[1],<fieldcode>[2]
  // Note: NO comma between field code and [2] — that's critical!
  // Each FORMAT header is followed by data rows: SKU,value
  const lines = [];

  // ── Prepare product data ──
  const parsed = [];
  for (const p of products) {
    const sku = String(p.sku || '').trim();
    if (!sku) continue;
    parsed.push({
      sku,
      desc: String(p.name || '').substring(0, 30).toUpperCase(),
      priceX100: Math.round(parseFloat(p.price || 0) * 100),
      costX100: Math.round(parseFloat(p.cost || 0) * 100),
      dept: String(p.department || '').trim(),
      vendorCode: String(p.vendor || '').trim().substring(0, 10).toLowerCase(),
      taxCode: String(p.taxCode || '4').trim(),
      reorderLvl: String(p.reorderLevel || '0').trim(),
      reorderQty: String(p.reorderQty || '0').trim(),
      priceType: String(p.priceType || '0').trim(),
    });
  }

  if (parsed.length === 0) {
    return res.status(400).json({ error: 'No valid products with SKUs' });
  }

  console.log(`[generate-pos-import] Building FORMAT batch for ${parsed.length} products`);

  // ── Field 2: PLU Number ──
  lines.push('FORMAT:183,1,[1],2[2]');
  for (const p of parsed) {
    lines.push(`${p.sku},${p.sku}`);
  }
  lines.push('');

  // ── Field 3: Description (30 chars max, uppercase) ──
  lines.push('FORMAT:183,1,[1],3[2]');
  for (const p of parsed) {
    lines.push(`${p.sku},${p.desc}`);
  }
  lines.push('');

  // ── Field 4: Department ──
  const withDept = parsed.filter(p => p.dept);
  if (withDept.length > 0) {
    lines.push('FORMAT:183,1,[1],4[2]');
    for (const p of withDept) {
      lines.push(`${p.sku},${p.dept}`);
    }
    lines.push('');
  }

  // ── Field 5: Price × 100 ──
  lines.push('FORMAT:183,1,[1],5[2]');
  for (const p of parsed) {
    lines.push(`${p.sku},${p.priceX100}`);
  }
  lines.push('');

  // ── Field 6: Cost × 100 ──
  const withCost = parsed.filter(p => p.costX100 > 0);
  if (withCost.length > 0) {
    lines.push('FORMAT:183,1,[1],6[2]');
    for (const p of withCost) {
      lines.push(`${p.sku},${p.costX100}`);
    }
    lines.push('');
  }

  // ── Field a: Tax Code ──
  lines.push('FORMAT:183,1,[1],a[2]');
  for (const p of parsed) {
    lines.push(`${p.sku},${p.taxCode}`);
  }
  lines.push('');

  // ── Field p: Vendor Code ──
  const withVendor = parsed.filter(p => p.vendorCode);
  if (withVendor.length > 0) {
    lines.push('FORMAT:183,1,[1],p[2]');
    for (const p of withVendor) {
      lines.push(`${p.sku},${p.vendorCode}`);
    }
    lines.push('');
  }

  // ── Field q: Re-order Level ──
  const withReorderLvl = parsed.filter(p => parseInt(p.reorderLvl) > 0);
  if (withReorderLvl.length > 0) {
    lines.push('FORMAT:183,1,[1],q[2]');
    for (const p of withReorderLvl) {
      lines.push(`${p.sku},${p.reorderLvl}`);
    }
    lines.push('');
  }

  // ── Field r: Re-order Qty ──
  const withReorderQty = parsed.filter(p => parseInt(p.reorderQty) > 0);
  if (withReorderQty.length > 0) {
    lines.push('FORMAT:183,1,[1],r[2]');
    for (const p of withReorderQty) {
      lines.push(`${p.sku},${p.reorderQty}`);
    }
    lines.push('');
  }

  // Use Windows line endings (CRLF) for Penny Lane compatibility
  const output = lines.join('\r\n');
  res.setHeader('Content-Type', 'text/plain');
  res.setHeader('Content-Disposition', 'attachment; filename="updateproduct.PLU"');
  return res.send(output);
});

// ─── Upload POS file to Firebase Storage (server-side) ──────
// POST /upload-pos-file
// Body: { content: "<file content string>" }
//
// This bypasses the browser Firebase Storage SDK entirely.
// The proxy uploads to Firebase Storage server-side using Admin SDK,
// which has no CORS issues.
app.post('/upload-pos-file', async (req, res) => {
  const { content } = req.body;
  if (!content || typeof content !== 'string') {
    return res.status(400).json({ error: 'Missing content string' });
  }

  console.log(`[upload-pos-file] Uploading ${content.length} chars to Firebase Storage`);

  try {
    const bucket = admin.storage().bucket();
    const latestFile = bucket.file('pos-imports/updateproduct.PLU');

    // Upload the latest file
    await latestFile.save(content, {
      contentType: 'text/plain',
      metadata: {
        metadata: {
          uploadedAt: new Date().toISOString(),
          source: 'sync-proxy',
        },
      },
    });
    console.log('[upload-pos-file] Latest file saved');

    // Make it publicly readable so the download URL works
    await latestFile.makePublic();

    // Get the public URL
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/pos-imports/updateproduct.PLU`;

    // Archive a timestamped copy (fire-and-forget)
    const ts = new Date().toISOString().replace(/:/g, '-').split('.')[0];
    const archiveFile = bucket.file(`pos-imports/archive/updateproduct_${ts}.PLU`);
    archiveFile.save(content, { contentType: 'text/plain' }).catch(err => {
      console.log(`[upload-pos-file] Archive failed (non-critical): ${err.message}`);
    });

    console.log(`[upload-pos-file] Success: ${publicUrl}`);

    return res.json({
      success: true,
      downloadUrl: publicUrl,
      publicUrl,
      size: content.length,
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    console.error('[upload-pos-file] Error:', err.message);
    return res.status(500).json({ error: err.message });
  }
});

// ─── Start server ───────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`sync-proxy running at http://localhost:${PORT}`);
  console.log(`Shop: ${SHOPIFY_SHOP}`);
  console.log(`Test: http://localhost:${PORT}/product-by-sku?sku=068656017070`);
});
