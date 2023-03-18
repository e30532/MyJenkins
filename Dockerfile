FROM maven:3.8-openjdk-11 as build
WORKDIR /app
COPY . .
RUN mvn install

FROM ibmcom/websphere-liberty:latest
MAINTAINER Yoshiki Yamada, e30532@jp.ibm.com
COPY --chown=1001:0  server.xml /config/server.xml
COPY --from=build /app/target/*.war //config/dropins/myjenkins.war
ARG VERBOSE=true
ENV WLP_LOGGING_CONSOLE_FORMAT=JSON
ENV WLP_LOGGING_CONSOLE_LOGLEVEL=info
ENV WLP_LOGGING_CONSOLE_SOURCE=message,trace,accessLog,ffdc,audit
RUN configure.sh

