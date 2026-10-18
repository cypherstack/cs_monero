ARG DEPENDS_IMAGE=cs_monero-depends:local
FROM ${DEPENDS_IMAGE}

ARG PLATFORMS="linux windows android"

# Copy only what build_libs.dart executes so unrelated tool changes do not
# invalidate the expensive build layer below.
COPY --chown=builder:builder tools/dart/env.dart tools/dart/util.dart \
    tools/dart/create_framework.dart /w/tools/dart/
COPY --chown=builder:builder tools/dart/bin/build_libs.dart \
    tools/dart/bin/prepare_monero_c.dart /w/tools/dart/bin/
COPY --chown=builder:builder patches /w/patches

# A reused depends image may embed another pin's checkout; prepare syncs it.
RUN dart tools/dart/bin/prepare_monero_c.dart

RUN --mount=type=secret,id=simplybs_mirror,uid=1000 \
    --mount=type=bind,source=cs_monero_flutter_libs_windows/windows/lib,target=/w/cs_monero_flutter_libs_windows/windows/lib \
    export SIMPLYBS_MIRROR="$(cat /run/secrets/simplybs_mirror 2>/dev/null || true)"; \
    for platform in ${PLATFORMS}; do \
      echo "==> build ${platform}" \
      && dart tools/dart/bin/build_libs.dart "${platform}" || exit 1; \
    done \
    && cd build/monero_c/contrib/depends/simplybs/.buildlib \
    && rm -rf source */built/*apple-sdk* */built/*/*apple-sdk*
