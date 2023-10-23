FROM ghcr.io/sdr-enthusiasts/docker-baseimage:base

ARG radarurl="ftp://public.tubby.org/radar-0.99.tar.gz"
ARG radarurlcreds="ftp:"

RUN set -x && \
    # define packages needed for installation and general management of the container:
    TEMP_PACKAGES=() && \
    KEPT_PACKAGES=() && \
    #
    TEMP_PACKAGES+=(pkg-config) && \
    TEMP_PACKAGES+=(build-essential) && \
    KEPT_PACKAGES+=(tcpdump) && \
    KEPT_PACKAGES+=(logrotate) && \
    # 
    # Install all the apt packages:
    apt-get update -q && \
    apt-get install -q -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -o Dpkg::Options::="--force-confold" -y --no-install-recommends  --no-install-suggests ${TEMP_PACKAGES[@]} ${KEPT_PACKAGES[@]} && \
    #
    # install stuff
    mkdir -p /src && \
    pushd /src && \
      curl -sSL -u $radarurlcreds $radarurl -o radar.tgz && \
      tar zxf radar.tgz && \
      mv -f radar-* radar && \
      cd radar && \
      make && \
      make install && \
    popd && \
    useradd -U -M -s /usr/sbin/nologin radar && \
    #
    # Clean up
    echo Uninstalling $TEMP_PACKAGES && \
    apt-get remove -y -q ${TEMP_PACKAGES[@]} && \
    apt-get autoremove -q -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -y && \
    apt-get clean -y -q && \
    rm -rf \
    /src/* \
    /tmp/* \
    /var/lib/apt/lists/* \
    /.dockerenv \
    /git
#
COPY rootfs/ /
#
RUN set -x && \
    #
    # Do some other stuff
    echo "alias dir=\"ls -alsv\"" >> /root/.bashrc && \
    echo "alias nano=\"nano -l\"" >> /root/.bashrc

HEALTHCHECK --interval=300s --timeout=30s --start-period=300s --start-interval=30s --retries=1 CMD /scripts/healthcheck.sh
#
# No need for SHELL and ENTRYPOINT as those are inherited from the base image
#
