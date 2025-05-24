# individual TeX Live versions
ARG BASE=scienhub/base:latest

FROM scienhub/texlive:2018 AS tl2018
FROM scienhub/texlive:2020 AS tl2020
FROM scienhub/texlive:2022 AS tl2022
FROM scienhub/texlive:2024 AS tl2024

# base image with necessary tools
FROM ${BASE} AS base

# copy and merge TeX Live versions
COPY --from=tl2018 /usr/local/texlive/2018 /usr/local/texlive/2018
COPY --from=tl2020 /usr/local/texlive/2020 /usr/local/texlive/2020
COPY --from=tl2022 /usr/local/texlive/2022 /usr/local/texlive/2022
COPY --from=tl2024 /usr/local/texlive/2024 /usr/local/texlive/2024

ENV LATEST_TL_VERSION=2024

# remove fonts from older versions and link to the latest version
RUN set -ex && for TL_VERSION in 2018 2020 2022; do \
        echo "Removing fonts for TeX Live $TL_VERSION..." && \
        rm -rf /usr/local/texlive/${TL_VERSION}/texmf-dist/fonts && \
        echo "Linking fonts for TeX Live $TL_VERSION..." && \
        ln -s /usr/local/texlive/${LATEST_TL_VERSION}/texmf-dist/fonts \
                /usr/local/texlive/${TL_VERSION}/texmf-dist/fonts; \
    done

RUN set -ex && for TL_VERSION in 2018 2020 2022 2024; do \
    rm -rf /usr/local/texlive/${TL_VERSION}/texmf-dist/doc \
        /usr/local/texlive/${TL_VERSION}/texmf-dist/source \
        /usr/local/texlive/${TL_VERSION}/tlpkg; \
    done

# delete other unnecessary files
RUN find /usr/local/texlive -name '*.log' -delete


# build the final image
FROM ${BASE} AS final

RUN apt update && \
    # basic utilities for TeX Live installation
    apt install -qy --no-install-recommends \
    # miscellaneous dependencies for TeX Live tools
    # for pdf snapshot
    graphicsmagick \
    # for eps conversion (see #14)
    ghostscript \
    # for gnuplot backend of pgfplots (see !13)
    gnuplot-nox \
    # convert LaTeX to HTML
    latexml \
    && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* \
           /var/cache/apt/* \
           /usr/share/doc/* \
           /usr/share/man/* \
           /usr/share/info/* \
           /tmp/*

COPY --from=base /usr/local/texlive /usr/local/texlive

ENV LATEST_TL_VERSION=2024

RUN mkdir -p /usr/local/bin/texlive

RUN set -x && for TL_VERSION in 2018 2020 2022 2024; do \
        echo "Configuring TeX Live $TL_VERSION..." && \
        # symlink executables
        ln -s /usr/local/texlive/${TL_VERSION}/bin/x86_64-linux \
            /usr/local/bin/texlive/${TL_VERSION} && \
        # update PATH and run TeX tools
        env PATH="/usr/local/bin/texlive/${TL_VERSION}" luaotfload-tool -u > /dev/null 2>&1 && \
        env PATH="/usr/local/bin/texlive/${TL_VERSION}" mtxrun --generate > /dev/null 2>&1 && \
        env PATH="/usr/local/bin/texlive/${TL_VERSION}" texlua "/usr/local/texlive/${TL_VERSION}/texmf-dist/scripts/context/lua/mtxrun.lua" --luatex --generate > /dev/null 2>&1 && \
        env PATH="/usr/local/bin/texlive/${TL_VERSION}" context --make > /dev/null 2>&1 && \
        env PATH="/usr/local/bin/texlive/${TL_VERSION}" context --luatex --make > /dev/null 2>&1; \
    done && \
    cp "/usr/local/texlive/${LATEST_TL_VERSION}/texmf-var/fonts/conf/texlive-fontconfig.conf" \
        "/etc/fonts/conf.d/09-texlive${LATEST_TL_VERSION}-fonts.conf" && \
    fc-cache -fsv > /dev/null 2>&1

# test
RUN set -x && for TL_VERSION in 2018 2020 2022 2024; do \
        echo "Testing TeX Live $TL_VERSION..." && \
        env PATH="/usr/local/bin/texlive/${TL_VERSION}" pdflatex --version && \
        env PATH="/usr/local/bin/texlive/${TL_VERSION}" xelatex --version && \
        env PATH="/usr/local/bin/texlive/${TL_VERSION}" lualatex --version; \
    done && \
    node --version
