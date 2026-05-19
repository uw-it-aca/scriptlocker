FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y && \
  apt-get upgrade -y && \
  apt-get dist-upgrade -y && \
  apt-get clean && \
  apt-get install --no-install-recommends -y \
  curl \
  less \
  python3.12-dev \
  python3-venv \
  python3-pip \
  tar && \
  rm -rf /var/lib/apt/lists

RUN curl -fsSL https://gh.io/copilot-install | bash
