/**
 * Auth Option 2 - Shared header token (lightweight).
 *
 * A single shared secret held in the ADMIN_TOKEN env var, checked inside the
 * Lambda. Cheaper and simpler than an API Key, but it's one shared secret with
 * no usage plan - use only for small internal/family apps.
 *
 * The token value comes from the environment, NEVER hardcode it and never commit
 * it. Set it at deploy time (e.g. CloudFormation parameter -> Lambda env var, or
 * SSM). Provide a .env.example listing ADMIN_TOKEN with an empty value.
 */

/**
 * Returns an error response object if auth fails, or null if it passes.
 *
 *   const authError = requireTokenAuth(event);
 *   if (authError) return authError;
 */
function requireTokenAuth(event) {
  const adminToken = process.env.ADMIN_TOKEN;

  if (!adminToken) {
    console.error('ADMIN_TOKEN environment variable not set');
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Server configuration error' }),
    };
  }

  const headers = event.headers || {};
  const providedToken = headers['X-Admin-Token'] || headers['x-admin-token'];

  if (!providedToken || providedToken !== adminToken) {
    return {
      statusCode: 401,
      body: JSON.stringify({ error: 'Unauthorized' }),
    };
  }

  return null; // authenticated
}

module.exports = { requireTokenAuth };

/*
 * ---- Frontend admin page pattern -------------------------------------------
 *
 * // Bootstrap from ?token=, store it, then strip it from the URL.
 * const params = new URLSearchParams(location.search);
 * const urlToken = params.get('token');
 * if (urlToken) {
 *   localStorage.setItem('adminToken', urlToken);
 *   history.replaceState({}, '', location.pathname);
 * }
 * const adminToken = localStorage.getItem('adminToken');
 *
 * await fetch(`${BASE_URL}/admin/resource`, {
 *   method: 'POST',
 *   headers: { 'X-Admin-Token': adminToken, 'Content-Type': 'application/json' },
 *   body: JSON.stringify(payload),
 * });
 *
 * ---- Rate limiting note -----------------------------------------------------
 * This option has no built-in usage plan. Add throttling separately, e.g. the
 * serverless-api-gateway-throttling plugin (stage-level: ~10 req/s, burst 50).
 */
