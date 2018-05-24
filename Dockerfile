FROM liveui/boost-base:1.0

WORKDIR /boost

ADD scripts ./scripts
ADD Sources ./Sources
ADD Tests ./Tests
ADD Package.swift ./

RUN swift build --configuration debug

