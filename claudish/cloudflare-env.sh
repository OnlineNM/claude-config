# Source this file to set up the environment for the `cloudflare-glm` claudish profile:
#   source ~/.claudish/cloudflare-env.sh
#
# Sets the Cloudflare account id + API token (used by the
# customEndpoints["cloudflare-glm"] entry in ~/.claudish/config.json, via
# baseUrl: ".../accounts/${CLOUDFLARE_ACCOUNT_ID}/ai" and
# apiKey: "${CUSTOM_CLOUDFLARE_GLM_KEY}") and unsets other providers' env vars
# that could otherwise hijack routing (Zhipu/GLM direct, OpenRouter, Anthropic
# passthrough, generic OpenAI).
#
# Note: ${VAR} interpolation in customEndpoints fields (baseUrl, apiKey, etc.)
# requires the local claudish patch — see ~/.claudish/reapply-patch.py.

unset ZHIPU_API_KEY
unset ZHIPU_API_BASE_URL
unset ANTHROPIC_BASE_URL
unset ANTHROPIC_AUTH_TOKEN
unset OPENROUTER_API_KEY
unset OPENROUTER_BASE_URL
unset OPENAI_API_KEY
unset OPENAI_BASE_URL

echo "[cloudflare-env] CUSTOM_CLOUDFLARE_GLM_KEY set; conflicting provider env vars unset."