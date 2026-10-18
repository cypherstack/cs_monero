FROM --platform=linux/amd64 ubuntu:26.04@sha256:3131b4cc82a783df6c9df078f86e01819a13594b865c2cad47bd1bca2b7063bb AS base

ARG DART_VERSION=3.12.2
ARG DART_SHA256=28e47b44cf075f36771046c068bb0d174201cf9c7608744aed1cc23204299c2d

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        autoconf automake build-essential ca-certificates clang cmake curl \
        file gcc-x86-64-linux-gnu gettext git golang gperf libtool llvm make \
        patch pkg-config python3 sudo texinfo unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/dart.zip \
      "https://storage.googleapis.com/dart-archive/channels/stable/release/${DART_VERSION}/sdk/dartsdk-linux-x64-release.zip" \
    && echo "${DART_SHA256}  /tmp/dart.zip" | sha256sum -c - \
    && unzip -q /tmp/dart.zip -d /usr/lib \
    && rm /tmp/dart.zip
ENV PATH="/usr/lib/dart-sdk/bin:${PATH}"

RUN userdel -r ubuntu \
    && useradd -ms /bin/bash -u 1000 builder \
    && printf 'builder ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/builder \
    && chmod 0440 /etc/sudoers.d/builder \
    && mkdir -p /w \
    && chown builder:builder /w
USER builder
WORKDIR /w

RUN git config --global user.name "cs_monero builder" \
    && git config --global user.email "builder@users.noreply.github.com" \
    && git config --global --add safe.directory '*'


FROM base AS depends

ARG SOURCE_URL=
LABEL org.opencontainers.image.source=$SOURCE_URL

ARG DEPENDS_TARGETS="x86_64-linux-gnu x86_64-w64-mingw32 x86_64-linux-android armv7a-linux-androideabi aarch64-linux-android"

COPY --chown=builder:builder tools/dart/env.dart tools/dart/util.dart /w/tools/dart/
COPY --chown=builder:builder tools/dart/bin/prepare_monero_c.dart tools/dart/bin/sbs_cleanup.dart /w/tools/dart/bin/
COPY --chown=builder:builder patches /w/patches

RUN dart tools/dart/bin/prepare_monero_c.dart

# SIMPLYBS_MIRROR (apple targets only) comes in as a BuildKit secret.
# Each completed target is stamped under .buildlib/complete so
# depends_usable.sh can reject partially built images.
# The image retains no Apple SDK: the apple-sdk package artifacts (simplybs
# stores native packages directly under built/, target packages under
# built/<triple>/) and the source cache are removed to prevent hosting the
# apple sdk in a public image.
RUN --mount=type=secret,id=simplybs_mirror,uid=1000 \
    export SIMPLYBS_MIRROR="$(cat /run/secrets/simplybs_mirror 2>/dev/null || true)"; \
    sbs=build/monero_c/contrib/depends/simplybs; \
    for target in ${DEPENDS_TARGETS}; do \
      echo "==> depends ${target}"; \
      (cd build/monero_c/contrib/depends && make HOST="${target}") || exit 1; \
      dart tools/dart/bin/sbs_cleanup.dart || exit 1; \
      mkdir -p "${sbs}/.buildlib/complete" \
        && touch "${sbs}/.buildlib/complete/${target}" || exit 1; \
    done \
    && cd "${sbs}/.buildlib" \
    && rm -rf source */built/*apple-sdk* */built/*/*apple-sdk*
