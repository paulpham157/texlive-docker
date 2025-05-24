# install texlive of a specific version
ARG BASE=scienhub/base
FROM ${BASE}

ARG TL_VERSION=2024
ARG TL_MIRROR
ARG GENERATE_CACHES=yes

RUN apt update && \
    # basic utilities for TeX Live installation
    apt install -qy --no-install-recommends \
    wget curl git unzip gnupg2 \
    # miscellaneous dependencies for TeX Live tools
    make fontconfig perl libgetopt-long-descriptive-perl \
    # default-jre \
    libdigest-perl-md5-perl libncurses6 \
    # for pdf snapshot
    graphicsmagick \
    # for latexindent (see #13)
    libunicode-linebreak-perl libfile-homedir-perl libyaml-tiny-perl \
    # for eps conversion (see #14)
    ghostscript \
    # for metafont (see #24)
    libsm6 \
    # for syntax highlighting
    python3 python3-pygments \
    # for gnuplot backend of pgfplots (see !13)
    gnuplot-nox \
    # convert LaTeX to HTML
    latexml \
    && \
    # bad fix for python handling
    ln -s /usr/bin/python3 /usr/bin/python && \
    # install texlive
    echo "Install texlive ${TL_VERSION}" && \
    mkdir -p "/tmp/${TL_VERSION}" && cd "/tmp/${TL_VERSION}" && \
    # wget --quiet https://tug.org/texlive/files/texlive.asc && \
    # gpg --import texlive.asc && \
    # rm texlive.asc && \
    wget --quiet "${TL_MIRROR}/install-tl-unx.tar.gz" && \
    # wget --quiet ${TL_MIRROR}/install-tl-unx.tar.gz.sha512 && \
    # wget --quiet ${TL_MIRROR}/install-tl-unx.tar.gz.sha512.asc && \
    # wget --quiet ${TL_MIRROR}/install-tl-unx.tar.gz && \
    # gpg --verify install-tl-unx.tar.gz.sha512.asc && \
    # sha512sum -c install-tl-unx.tar.gz.sha512 && \
    tar -x --strip-components=1 -f install-tl-unx.tar.gz && \
    echo "selected_scheme scheme-full" > install.profile && \
    echo "tlpdbopt_install_docfiles 0" >> install.profile && \
    echo "tlpdbopt_install_srcfiles 0" >> install.profile && \
    echo "tlpdbopt_autobackup 0" >> install.profile && \
    echo "tlpdbopt_sys_bin /usr/bin" >> install.profile && \
    if [ "$TL_VERSION" = "2019" ]; then \
        # a trick for texlive 2019 because it couldn't pass the signature check
        ./install-tl -profile install.profile -repository ${TL_MIRROR} -no-verify-downloads; \
    else \
        ./install-tl -profile install.profile -repository ${TL_MIRROR}; \
    fi && \
    rm -rf "/tmp/${TL_VERSION}" && \
    apt remove -qy wget curl git unzip gnupg2 && \
    apt clean && \
    apt purge -y --auto-remove && \
    rm -rf /var/lib/apt/lists/* \
           /var/cache/apt/* \
           /usr/share/doc/* \
           /usr/share/man/* \
           /usr/share/info/* \
           /tmp/*

RUN echo "Set PATH to $PATH" && \
    $(find /usr/local/texlive -name tlmgr) path add && \
    # Temporary fix for ConTeXt (#30)
    (sed -i '/package.loaded\["data-ini"\]/a if os.selfpath then environment.ownbin=lfs.symlinktarget(os.selfpath..io.fileseparator..os.selfname);environment.ownpath=environment.ownbin:match("^.*"..io.fileseparator) else environment.ownpath=kpse.new("luatex"):var_value("SELFAUTOLOC");environment.ownbin=environment.ownpath..io.fileseparator..(arg[-2] or arg[-1] or arg[0] or "luatex"):match("[^"..io.fileseparator.."]*$") end' "/usr/local/texlive/${TL_VERSION}/texmf-dist/scripts/context/lua/mtxrun.lua" || true) && \
    # pregenerate caches as per #3; overhead is < 5 MB which does not really
    # matter for images in the sizes of GBs; some TL schemes might not have
    # all the tools, therefore failure is allowed
    if [ "$GENERATE_CACHES" = "yes" ]; then \
        echo "Generating caches and ConTeXt files" && \
        (luaotfload-tool -u > /dev/null 2>&1 || true) && \
        # also generate fontconfig cache as per #18 which is approx. 20 MB but
        # benefits XeLaTeX user to load fonts from the TL tree by font name
        (cp "$(find /usr/local/texlive -name texlive-fontconfig.conf)" /etc/fonts/conf.d/09-texlive-fonts.conf || true) && \
        fc-cache -fsv > /dev/null 2>&1 && \
        mtxrun --generate > /dev/null 2>&1 && \
        texlua "/usr/local/texlive/${TL_VERSION}/texmf-dist/scripts/context/lua/mtxrun.lua" --luatex --generate && \
        context --make > /dev/null 2>&1 && \
        context --luatex --make > /dev/null 2>&1; \
    fi

RUN \
    # test the installation; we only test the full installation because
    # in that, all tools are present and have to work
    latex --version && printf '\n' && \
    biber --version && printf '\n' && \
    # xindy --version && printf '\n' && \
    # arara --version && printf '\n' && \
    context --version && printf '\n' && \
    context --luatex --version
