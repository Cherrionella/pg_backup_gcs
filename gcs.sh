#!/usr/bin/env bash

# Inspired by implementation by Will Haley at:
#   http://willhaley.com/blog/generate-jwt-with-bash/

scope='https://www.googleapis.com/auth/devstorage.read_write'
service='https://oauth2.googleapis.com/token'

# Shared content to use as template
header_template='{
    "typ": "JWT"
}'

payload_template='{}'

build_header() {
    jq -c \
        --arg alg "${1:-HS256}" \
        --arg kid "${2}" \
        '
        .alg = $alg
        ' <<<"$header_template" | tr -d '\n'
}

build_payload() {
    jq -c \
        --arg iat_str "$(date +%s)" \
        --arg acc "${1}" \
        --arg aud "${service}" \
        --arg scope "${scope}" \
        '
        ($iat_str | tonumber) as $iat
        | .iss = $acc
        | .scope = $scope
        | .aud = $aud
        | .exp = ($iat + 1)
        | .iat = $iat
        ' <<<"$payload_template" | tr -d '\n'
}

b64enc() { openssl enc -base64 -A | tr '+/' '-_' | tr -d '='; }
json() { jq -c . | LC_CTYPE=C tr -d '\n'; }
hs_sign() { openssl dgst -binary -sha"${1}" -hmac "$2"; }
rs_sign() { openssl dgst -binary -sha"${1}" -sign <(printf '%s\n' "$2"); }

sign() {
        local algo payload header sig kid iss acc secret secret_file=$2
        algo=${1:-RS256}; algo=${algo^^}
        kid=$(jq -r '.private_key_id' ${secret_file})
        acc=$(jq -r '.client_email' ${secret_file})
        secret=$(jq -r '.private_key' ${secret_file})
        header=$(build_header "$algo" "$kid") || return
        payload=$(build_payload "$acc") || return
        signed_content="$(json <<<"$header" | b64enc).$(json <<<"$payload" | b64enc)"
        case $algo in
                HS*) sig=$(printf %s "$signed_content" | hs_sign "${algo#HS}" "$secret" | b64enc) ;;
                RS*) sig=$(printf %s "$signed_content" | rs_sign "${algo#RS}" "$secret" | b64enc) ;;
                *) echo "Unknown algorithm" >&2; return 1 ;;
        esac
        printf '%s.%s\n' "${signed_content}" "${sig}"
}

function upload() {
    local jwt response content_type bucket=$1 upload_file=$2 object_name=$3 secret_file=$4

    jwt=$(sign "rs256" $secret_file)
    response=$(curl -s -d 'grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion='$jwt'' https://oauth2.googleapis.com/token)
    token=$(jq -r '.access_token' <<<"$response")
    content_type=$(file -b --mime-type ${upload_file})

    curl -s -X POST --data-binary @${upload_file} \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: ${content_type}" \
        "https://storage.googleapis.com/upload/storage/v1/b/${bucket}/o?uploadType=media&name=${object_name}"
}