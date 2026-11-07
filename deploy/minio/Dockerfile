# Docker Hub/Quay không còn image MinIO công khai (kiểm tra 11/2026). Chainguard có minio + mc nhưng không có shell,
# còn compose cần shell cho minio-init -> chép hai file chạy vào image nền có shell.
FROM cgr.dev/chainguard/minio:latest AS minio
FROM cgr.dev/chainguard/minio-client:latest AS mc
FROM cgr.dev/chainguard/wolfi-base:latest
COPY --from=minio /usr/bin/minio /usr/bin/minio
COPY --from=mc /usr/bin/mc /usr/bin/mc
RUN mkdir -p /data && chown 65532:65532 /data
USER 65532
ENTRYPOINT ["/usr/bin/minio"]
