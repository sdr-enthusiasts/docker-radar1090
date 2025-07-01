FROM ghcr.io/sdr-enthusiasts/docker-baseimage:base AS build

ARG radar_base_url="https://1090mhz.uk/files/"
ARG radar_repo="https://github.com/G8TIC/radar.git"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN set -x && \
  # define packages needed for installation and general management of the container:
  TEMP_PACKAGES=() && \
  TEMP_PACKAGES+=(pkg-config) && \
  TEMP_PACKAGES+=(build-essential) && \
  TEMP_PACKAGES+=(git) && \
  # Install all the apt packages:
  apt-get update -q && \
  apt-get install -q -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -o Dpkg::Options::="--force-confold" -y --no-install-recommends  --no-install-suggests "${TEMP_PACKAGES[@]}" "${KEPT_PACKAGES[@]}" && \
  #
  # install stuff
  mkdir -p /src && \
  pushd /src && \
  # old method was to get the source from the $radar_base_url website:
  # version="$(curl -sSL ${radar_base_url}/version.txt)" &&\
  # curl -sSL ${radar_base_url}/${version}.tar.gz -o radar.tgz && \
  # tar zxf radar.tgz && \
  # mv -f radar-* radar && \
  #
  # new method is to get the source from the github repo:
  git clone --depth=1 "${radar_repo}" radar && \
  cd radar && \
  make && \
  make install && \
  popd || exit 1

FROM ghcr.io/sdr-enthusiasts/docker-baseimage:base

COPY --from=build /usr/sbin/radar /usr/sbin/radar

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN set -x && \
  # define packages needed for installation and general management of the container:
  KEPT_PACKAGES=() && \
  KEPT_PACKAGES+=(tcpdump) && \
  KEPT_PACKAGES+=(logrotate) && \
  #
  # Install all the apt packages:
  apt-get update -q && \
  apt-get install -q -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -o Dpkg::Options::="--force-confold" -y --no-install-recommends  --no-install-suggests "${TEMP_PACKAGES[@]}" "${KEPT_PACKAGES[@]}" && \
  #
  # add user for radar to run as
  useradd -U -M -s /usr/sbin/nologin radar && \
  #
  # Clean up
  echo Autoremoving/cleaning APT && \
  apt-get autoremove -q -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -y && \
  apt-get clean -y -q && \
  rm -rf \
  /src/* \
  /tmp/* \
  /var/lib/apt/lists/* \
  /.dockerenv \
  /git && \
  #
  # add version to the container
  version="$(/usr/sbin/radar -v | sed 's/^.*Version \(.*\)$/\1/g;q')" && \
  echo "${version// /_} ($(uname -m))" > /.CONTAINER_VERSION
#
COPY rootfs/ /
#
RUN set -x && \
  #
  # Do some other stuff
  echo "alias dir=\"ls -alsv\"" >> /root/.bashrc && \
  echo "alias nano=\"nano -l\"" >> /root/.bashrc

HEALTHCHECK --interval=300s --timeout=30s --start-period=300s --retries=1 CMD /scripts/healthcheck.sh
#
# No need for SHELL and ENTRYPOINT as those are inherited from the base image
#
