FROM cgr.dev/chainguard/wolfi-base:latest
ARG action=create
RUN apk add -u curl jq redis-cli
COPY ./scripts/${action}.sh /acorn/scripts/render.sh
ENTRYPOINT ["/acorn/scripts/render.sh"]