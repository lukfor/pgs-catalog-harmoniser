FROM continuumio/miniconda3
MAINTAINER Lukas Forer <lukas.forer@i-med.ac.at>

COPY environment.yml .
RUN \
   conda env update -n root -f environment.yml \
&& conda clean -a

# Install jbang (not as conda package available)
WORKDIR "/opt"
RUN wget https://github.com/jbangdev/jbang/releases/download/v0.78.0/jbang.zip && \
    unzip -q jbang.zip && \
    rm jbang.zip
ENV PATH="/opt/jbang/bin:${PATH}"

# Install pgs-calc (not as conda package available)
ENV PGS_CALC_VERSION="1.3.4"
RUN mkdir /opt/pgs-calc
WORKDIR "/opt/pgs-calc"
RUN wget https://github.com/lukfor/pgs-calc/releases/download/v${PGS_CALC_VERSION}/pgs-calc-${PGS_CALC_VERSION}.tar.gz && \
    tar -xf pgs-calc-*.tar.gz
ENV PATH="/opt/pgs-calc:${PATH}"

RUN apt-get --allow-releaseinfo-change update && apt-get install -y tabix
