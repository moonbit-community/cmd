FROM ubuntu@sha256:2e863c44b718727c860746568e1d54afd13b2fa71b160f5cd9058fc436217b30 AS toolchain

ARG DEBIAN_FRONTEND=noninteractive
ARG COREUTILS_VERSION=9.11
ARG COREUTILS_SHA256=394024eda0a5955217ceda9cd1201e65dc8fa3aa29c2951135a49521d57c3cc3
ARG DIFFUTILS_VERSION=3.12
ARG DIFFUTILS_SHA256=7c8b7f9fc8609141fdea9cece85249d308624391ff61dedaf528fcb337727dfd
ARG FINDUTILS_VERSION=4.10.0
ARG FINDUTILS_SHA256=1387e0b67ff247d2abde998f90dfbf70c1491391a59ddfecb8ae698789f0a4f5
ARG GREP_VERSION=3.12
ARG GREP_SHA256=2649b27c0e90e632eadcd757be06c6e9a4f48d941de51e7c0f83ff76408a07b9
ARG WGET_VERSION=1.25.0
ARG WGET_SHA256=766e48423e79359ea31e41db9e5c289675947a7fcf2efdcedb726ac9d0da3784
ARG MAKE_VERSION=4.4.1
ARG MAKE_SHA256=8814ba072182b605d156d7589c19a43b89fc58ea479b9355146160946f8cf6e9
ARG CURL_VERSION=8.22.0
ARG CURL_SHA256=f7ef3ae8a22e521f289803fe93543eb64c329b58aa73a9e224dfd915a2a5f4f7
ARG DASH_VERSION=0.5.12
ARG DASH_SHA256=0d632f6b945058d84809cac7805326775bd60cb4a316907d0bd4228ff7107154
ARG JQ_VERSION=1.8.2
ARG JQ_SHA256=b1c22172dd303f3be49e935aa56aa48a8b7a46e0bc838b4997d3bb451495870f
ARG VIM_VERSION=9.1.0000
ARG VIM_SHA256=8d2a74e358be9cf260174e15e2e29dba4773f2670718b5bf728db6f54b90e25d
ARG SED_VERSION=4.9
ARG SED_SHA256=6e226b732e1cd739464ad6862bd1a1aba42d7982922da7a53519631d24975181
ARG PATCH_VERSION=2.8
ARG PATCH_SHA256=f87cee69eec2b4fcbf60a396b030ad6aa3415f192aa5f7ee84cad5e11f7f5ae3
ARG GZIP_VERSION=1.14
ARG GZIP_SHA256=01a7b881bd220bfdf615f97b8718f80bdfd3f6add385b993dcf6efd14e8c0ac6
ARG UTIL_LINUX_VERSION=2.40
ARG UTIL_LINUX_SHA256=d57a626081f9ead02fa44c63a6af162ec19c58f53e993f206ab7c3a6641c2cd7

RUN apt-get update \
  && apt-get install --yes --no-install-recommends \
    autoconf \
    automake \
    build-essential \
    ca-certificates \
    curl \
    gettext \
    libbrotli-dev \
    libidn2-dev \
    libnghttp2-dev \
    libonig-dev \
    libpcre2-dev \
    libpsl-dev \
    libssl-dev \
    libtool \
    libunistring-dev \
    libzstd-dev \
    lzip \
    pkg-config \
    xz-utils \
    zlib1g-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN mkdir -p /oracle/bin

FROM toolchain AS build-coreutils

RUN curl --fail --location --retry 5 \
      "https://ftp.gnu.org/gnu/coreutils/coreutils-${COREUTILS_VERSION}.tar.xz" \
      --output coreutils.tar.xz \
  && echo "${COREUTILS_SHA256}  coreutils.tar.xz" | sha256sum --check --strict \
  && tar --extract --file coreutils.tar.xz \
  && cd "coreutils-${COREUTILS_VERSION}" \
  && FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/oracle --disable-nls \
  && make -j2 \
  && make install-strip \
  && cd /build \
  && rm -rf coreutils.tar.xz "coreutils-${COREUTILS_VERSION}"

FROM toolchain AS build-diffutils

RUN curl --fail --location --retry 5 \
      "https://ftp.gnu.org/gnu/diffutils/diffutils-${DIFFUTILS_VERSION}.tar.xz" \
      --output diffutils.tar.xz \
  && echo "${DIFFUTILS_SHA256}  diffutils.tar.xz" | sha256sum --check --strict \
  && tar --extract --file diffutils.tar.xz \
  && cd "diffutils-${DIFFUTILS_VERSION}" \
  && ./configure --prefix=/oracle --disable-nls \
  && make -j2 \
  && make install-strip \
  && cd /build \
  && rm -rf diffutils.tar.xz "diffutils-${DIFFUTILS_VERSION}"

FROM toolchain AS build-findutils

RUN curl --fail --location --retry 5 \
      "https://ftp.gnu.org/gnu/findutils/findutils-${FINDUTILS_VERSION}.tar.xz" \
      --output findutils.tar.xz \
  && echo "${FINDUTILS_SHA256}  findutils.tar.xz" | sha256sum --check --strict \
  && tar --extract --file findutils.tar.xz \
  && cd "findutils-${FINDUTILS_VERSION}" \
  && ./configure --prefix=/oracle --disable-nls \
  && make -j2 \
  && make install-strip \
  && cd /build \
  && rm -rf findutils.tar.xz "findutils-${FINDUTILS_VERSION}"

FROM toolchain AS build-grep

RUN curl --fail --location --retry 5 \
      "https://ftp.gnu.org/gnu/grep/grep-${GREP_VERSION}.tar.xz" \
      --output grep.tar.xz \
  && echo "${GREP_SHA256}  grep.tar.xz" | sha256sum --check --strict \
  && tar --extract --file grep.tar.xz \
  && cd "grep-${GREP_VERSION}" \
  && ./configure --prefix=/oracle --disable-nls \
  && make -j2 \
  && make install-strip \
  && cd /build \
  && rm -rf grep.tar.xz "grep-${GREP_VERSION}"

FROM toolchain AS build-wget

RUN curl --fail --location --retry 5 \
      "https://ftp.gnu.org/gnu/wget/wget-${WGET_VERSION}.tar.gz" \
      --output wget.tar.gz \
  && echo "${WGET_SHA256}  wget.tar.gz" | sha256sum --check --strict \
  && tar --extract --file wget.tar.gz \
  && cd "wget-${WGET_VERSION}" \
  && ./configure --prefix=/oracle --disable-nls --with-ssl=openssl \
  && make -j2 \
  && make install-strip \
  && cd /build \
  && rm -rf wget.tar.gz "wget-${WGET_VERSION}"

FROM toolchain AS build-make

RUN curl --fail --location --retry 5 \
      "https://ftp.gnu.org/gnu/make/make-${MAKE_VERSION}.tar.lz" \
      --output make.tar.lz \
  && echo "${MAKE_SHA256}  make.tar.lz" | sha256sum --check --strict \
  && tar --extract --lzip --file make.tar.lz \
  && cd "make-${MAKE_VERSION}" \
  && ./configure --prefix=/oracle --disable-nls \
  && make -j2 \
  && make install-strip \
  && cd /build \
  && rm -rf make.tar.lz "make-${MAKE_VERSION}"

FROM toolchain AS build-curl

RUN curl --fail --location --retry 5 \
      "https://curl.se/download/curl-${CURL_VERSION}.tar.xz" \
      --output curl.tar.xz \
  && echo "${CURL_SHA256}  curl.tar.xz" | sha256sum --check --strict \
  && tar --extract --file curl.tar.xz \
  && cd "curl-${CURL_VERSION}" \
  && ./configure --prefix=/oracle --disable-nls --with-openssl \
  && make -j2 \
  && make install-strip \
  && cd /build \
  && rm -rf curl.tar.xz "curl-${CURL_VERSION}"

FROM toolchain AS build-dash

RUN curl --fail --location --retry 5 \
      "https://git.kernel.org/pub/scm/utils/dash/dash.git/snapshot/dash-${DASH_VERSION}.tar.gz" \
      --output dash.tar.gz \
  && echo "${DASH_SHA256}  dash.tar.gz" | sha256sum --check --strict \
  && tar --extract --file dash.tar.gz \
  && cd "dash-${DASH_VERSION}" \
  && autoreconf --force --install \
  && ./configure --prefix=/oracle \
  && make -j2 \
  && make install-strip \
  && cd /build \
  && rm -rf dash.tar.gz "dash-${DASH_VERSION}"

FROM toolchain AS build-jq

RUN curl --fail --location --retry 5 \
      "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-amd64" \
      --output /oracle/bin/jq \
  && echo "${JQ_SHA256}  /oracle/bin/jq" | sha256sum --check --strict \
  && chmod 0755 /oracle/bin/jq

FROM toolchain AS build-vim

RUN curl --fail --location --retry 5 \
      "https://github.com/vim/vim/archive/refs/tags/v${VIM_VERSION}.tar.gz" \
      --output vim.tar.gz \
  && echo "${VIM_SHA256}  vim.tar.gz" | sha256sum --check --strict \
  && tar --extract --file vim.tar.gz \
  && make -C "vim-${VIM_VERSION}/src/xxd" \
  && install -m 0755 "vim-${VIM_VERSION}/src/xxd/xxd" /oracle/bin/xxd \
  && rm -rf vim.tar.gz "vim-${VIM_VERSION}"

FROM toolchain AS build-sed

RUN curl --fail --location --retry 5 \
      "https://ftp.gnu.org/gnu/sed/sed-${SED_VERSION}.tar.xz" \
      --output sed.tar.xz \
  && echo "${SED_SHA256}  sed.tar.xz" | sha256sum --check --strict \
  && tar --extract --file sed.tar.xz \
  && cd "sed-${SED_VERSION}" \
  && ./configure --prefix=/oracle --disable-nls \
  && make -j2 \
  && make install-strip \
  && cd /build \
  && rm -rf sed.tar.xz "sed-${SED_VERSION}"

FROM toolchain AS build-patch

RUN curl --fail --location --retry 5 \
      "https://ftp.gnu.org/gnu/patch/patch-${PATCH_VERSION}.tar.xz" \
      --output patch.tar.xz \
  && echo "${PATCH_SHA256}  patch.tar.xz" | sha256sum --check --strict \
  && tar --extract --file patch.tar.xz \
  && cd "patch-${PATCH_VERSION}" \
  && ./configure --prefix=/oracle \
  && make -j2 \
  && make install-strip \
  && cd /build \
  && rm -rf patch.tar.xz "patch-${PATCH_VERSION}"

FROM toolchain AS build-gzip

RUN curl --fail --location --retry 5 \
      "https://ftp.gnu.org/gnu/gzip/gzip-${GZIP_VERSION}.tar.xz" \
      --output gzip.tar.xz \
  && echo "${GZIP_SHA256}  gzip.tar.xz" | sha256sum --check --strict \
  && tar --extract --file gzip.tar.xz \
  && cd "gzip-${GZIP_VERSION}" \
  && ./configure --prefix=/oracle \
  && make -j2 \
  && make install-strip \
  && cd /build \
  && rm -rf gzip.tar.xz "gzip-${GZIP_VERSION}"

FROM toolchain AS build-util-linux

RUN curl --fail --location --retry 5 \
      "https://www.kernel.org/pub/linux/utils/util-linux/v${UTIL_LINUX_VERSION}/util-linux-${UTIL_LINUX_VERSION}.tar.xz" \
      --output util-linux.tar.xz \
  && echo "${UTIL_LINUX_SHA256}  util-linux.tar.xz" | sha256sum --check --strict \
  && tar --extract --file util-linux.tar.xz \
  && cd "util-linux-${UTIL_LINUX_VERSION}" \
  && ./configure --prefix=/oracle --disable-nls --disable-shared --without-python --without-systemd --disable-liblastlog2 --without-ncursesw --without-ncurses \
  && make -j2 hexdump column rev \
  && install -m 0755 hexdump /oracle/bin/hexdump \
  && install -m 0755 column /oracle/bin/column \
  && install -m 0755 rev /oracle/bin/rev \
  && cd /build \
  && rm -rf util-linux.tar.xz "util-linux-${UTIL_LINUX_VERSION}"

FROM toolchain AS build-binutils

ARG BINUTILS_VERSION=2.44
ARG BINUTILS_SHA256=ce2017e059d63e67ddb9240e9d4ec49c2893605035cd60e92ad53177f4377237

RUN curl --fail --location --retry 5 \
      "https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.xz" \
      --output binutils.tar.xz \
  && echo "${BINUTILS_SHA256}  binutils.tar.xz" | sha256sum --check --strict \
  && tar --extract --file binutils.tar.xz \
  && cd "binutils-${BINUTILS_VERSION}" \
  && ./configure --prefix=/oracle --disable-nls --disable-gdb --disable-gprof --disable-gprofng --disable-gas --disable-ld --disable-gold --disable-sim --disable-werror --without-zstd --with-system-zlib \
  && make -j2 all-binutils \
  && install -m 0755 binutils/strings /oracle/bin/strings \
  && cd /build \
  && rm -rf binutils.tar.xz "binutils-${BINUTILS_VERSION}"

FROM toolchain AS build-tree

ARG TREE_VERSION=2.2.1
ARG TREE_SHA256=68ac45dc78c0c311ada06200ffc3c285e74223ba208061f8d15ffac25e44b2ec

RUN curl --fail --location --retry 5 \
      "https://oldmanprogrammer.net/tar/tree/tree-${TREE_VERSION}.tgz" \
      --output tree.tgz \
  && echo "${TREE_SHA256}  tree.tgz" | sha256sum --check --strict \
  && tar --extract --file tree.tgz \
  && make -C "tree-${TREE_VERSION}" -j2 \
  && install -m 0755 "tree-${TREE_VERSION}/tree" /oracle/bin/tree \
  && rm -rf tree.tgz "tree-${TREE_VERSION}"

FROM toolchain AS build-ripgrep

ARG RUST_VERSION=1.97.1
ARG RUST_SHA256=88f28fa9af20594179f85d6df67078dfd6fa93e2f6da5e1e9b0ac4997988ca4f
ARG RIPGREP_VERSION=3fce3b5bb0236da2df6d99672afb8a719642eca7
ARG RIPGREP_SHA256=e2c23831f1057a7e15575a72a64a900b317a86661561a786a36795717d602561

RUN curl --fail --location --retry 5 \
      "https://static.rust-lang.org/dist/rust-${RUST_VERSION}-x86_64-unknown-linux-gnu.tar.xz" \
      --output rust.tar.xz \
  && echo "${RUST_SHA256}  rust.tar.xz" | sha256sum --check --strict \
  && tar --extract --file rust.tar.xz \
  && "./rust-${RUST_VERSION}-x86_64-unknown-linux-gnu/install.sh" \
      --prefix=/opt/rust --components=rustc,cargo,rust-std-x86_64-unknown-linux-gnu --disable-ldconfig \
  && curl --fail --location --retry 5 \
      "https://codeload.github.com/BurntSushi/ripgrep/tar.gz/${RIPGREP_VERSION}" \
      --output ripgrep.tar.gz \
  && echo "${RIPGREP_SHA256}  ripgrep.tar.gz" | sha256sum --check --strict \
  && tar --extract --file ripgrep.tar.gz \
  && cd "ripgrep-${RIPGREP_VERSION}" \
  && PATH=/opt/rust/bin:$PATH cargo build --release --locked --bin rg \
  && install -m 0755 target/release/rg /oracle/bin/rg

FROM toolchain AS oracle

COPY --from=build-coreutils /oracle/ /oracle/
COPY --from=build-diffutils /oracle/ /oracle/
COPY --from=build-findutils /oracle/ /oracle/
COPY --from=build-grep /oracle/ /oracle/
COPY --from=build-wget /oracle/ /oracle/
COPY --from=build-make /oracle/ /oracle/
COPY --from=build-curl /oracle/ /oracle/
COPY --from=build-dash /oracle/ /oracle/
COPY --from=build-jq /oracle/ /oracle/
COPY --from=build-vim /oracle/ /oracle/
COPY --from=build-sed /oracle/ /oracle/
COPY --from=build-patch /oracle/ /oracle/
COPY --from=build-gzip /oracle/ /oracle/
COPY --from=build-util-linux /oracle/ /oracle/
COPY --from=build-binutils /oracle/ /oracle/
COPY --from=build-tree /oracle/ /oracle/
COPY --from=build-ripgrep /oracle/ /oracle/

RUN ln -s /oracle/bin/dash /oracle/bin/sh

COPY --chmod=0755 entrypoint.sh versions.sh /usr/local/bin/

ENV LANG=C LC_ALL=C TZ=UTC PATH=/oracle/bin SHELL=/oracle/bin/sh
WORKDIR /work
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
