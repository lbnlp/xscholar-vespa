cd xscholar-vespa
mvn clean install 
cd ..
docker image build --tag xscholar-vespa .
docker image tag xscholar-vespa:latest registry.nersc.gov/m3624/xscholar-vespa:$1
docker image push registry.nersc.gov/m3624/xscholar-vespa:$1
