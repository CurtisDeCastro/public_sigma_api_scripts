import axios from 'axios';

const clientId = process.env.CLIENT_ID; // Reference to environment variable for client ID
const embedSecret = process.env.EMBED_SECRET; // Reference to environment variable for embed secret
const cloudType = process.env.CLOUD_TYPE; // Reference to environment variable for cloud type

const baseUrls = {
  'AWS US': 'https://aws-api.sigmacomputing.com',
  'AWS Canada': 'https://api.ca.aws.sigmacomputing.com',
  'AWS Europe': 'https://api.eu.aws.sigmacomputing.com',
  'AWS UK': 'https://api.uk.aws.sigmacomputing.com',
  'Azure US': 'https://api.us.azure.sigmacomputing.com',
  'GCP': 'https://api.sigmacomputing.com'
};

const baseUrl = baseUrls[cloudType];
const authUrl = `${baseUrl}/v2/auth/token`;

const encodedParams = new URLSearchParams({client_id: clientId, client_secret: embedSecret});
encodedParams.set('grant_type', 'client_credentials');

const authOptions = {
  method: 'POST',
  url: authUrl,
  headers: {
    accept: 'application/json',
    'content-type': 'application/x-www-form-urlencoded'
  },
  data: encodedParams,
};

const cache = {}; // Global cache to store all embed URLs

async function getWorkbookUrlFromEmbedUrl(embedUrl) {
  if (cache[embedUrl]) {
    return cache[embedUrl];
  }

  try {
    const authResponse = await axios.request(authOptions);
    const access_token = authResponse.data.access_token;

    const workbookListOptions = {
      method: 'GET',
      url: `${baseUrl}/v2/workbooks`,
      headers: {
        accept: 'application/json',
        authorization: 'Bearer ' + access_token
      }
    };

    const workbookResponse = await axios.request(workbookListOptions);
    let allWorkbookIds = [];
    let workbookUrlMap = {};

    let currentEntries = workbookResponse.data.entries;
    let hasMore = workbookResponse.data.hasMore;
    let nextPage = workbookResponse.data.nextPage;

    while (currentEntries.length > 0) {
      currentEntries.forEach(entry => {
        allWorkbookIds.push(entry.workbookId);
        workbookUrlMap[entry.workbookId] = entry.url; // Store the workbook URL
      });

      if (!hasMore) break;

      const nextOptions = {
        method: 'GET',
        url: `${baseUrl}/v2/workbooks`,
        headers: {
          accept: 'application/json',
          authorization: 'Bearer ' + access_token
        },
        params: {
          page: nextPage
        }
      };

      const nextRes = await axios.request(nextOptions);
      currentEntries = nextRes.data.entries;
      hasMore = nextRes.data.hasMore;
      nextPage = nextRes.data.nextPage;
    }

    const embedPromises = allWorkbookIds.map(workbookId => {
      const embedOptions = {
        method: 'GET',
        url: `${baseUrl}/v2/workbooks/${workbookId}/embeds`,
        headers: {
          accept: 'application/json',
          authorization: 'Bearer ' + access_token
        }
      };

      return axios
        .request(embedOptions)
        .then(res => {
          res.data.entries.forEach(entry => {
            cache[entry.embedUrl] = workbookUrlMap[workbookId]; // Map embed URL to workbook URL
          });
        })
        .catch(err => console.error(err));
    });

    await Promise.all(embedPromises);

    // Comment in the line below to return the full list of mappings between your org's embed URLs and the parent workbook URLs
    // return cache;

    //Comment in the line below to return the single workbook URL associated with an embed path
    return cache[embedUrl] || null;

  } catch (err) {
    console.error(err);
    return null;
  }
}

// Example usage:
getWorkbookUrlFromEmbedUrl('yourEmbedPath').then(url => console.log(url));
