// kiro-template v2.0.0
/**
 * LIMITED USE, see security-standards v2 (decision table row d).
 * Shared header token: only for trivial, non-sensitive internal tools. Never for
 * personal data, money, or anything public-facing. Use Cognito for those.
 *
 * A single shared secret held in the ADMIN_TOKEN env var, checked inside the
 * Lambda. One shared secret, no per-client keys, no usage plan. Clients send it
 * in the X-Admin-Token header; the handler returns 401 on mismatch and 500 if
 * ADMIN_TOKEN is unset.
 *
 * The token value comes from the environment, NEVER hardcode it and never commit
 * it. Store it in SSM as a SecureString (scripts/setup-params.sh secure admin-token)
 * and have the Lambda read it at cold start (GetParameter with decryption, cached
 * in memory; IAM scoped to that one parameter ARN) and expose it as ADMIN_TOKEN.
 * Don't put it in a plain CloudFormation parameter or template.
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
 * This option has no built-in usage plan. Add stage-level throttling on the API
 * Gateway stage (MethodSettings, e.g. 10 req/s, burst 50; see api-stack.yaml).
 */
