FROM dipperroy/nodejs:alpine-7.9.0

MAINTAINER Dipper Roy <ruizhipeng001@gmail.com>

COPY . /opt/mongo

WORKDIR /opt/mongo

RUN npm install

CMD ["npm", "start"]
