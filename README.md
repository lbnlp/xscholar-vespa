# XScholar - Abstract Search

A simple Vespa application which can be deployed on four nodes within a [Spin application](https://www.nersc.gov/systems/spin/) for text search on a database of research paper abstracts.

## Spin Setup
For this stack we will need 4 servies: 
* db-admin0: Vespa admin node
* db-stateless0: Vespa search/feed node
* db-content0: Vespa content node.
* app-linux: Service for data transfer

### app-linux configuration
Set up this node to use the docker image at `registry.nersc.gov/m3624/app-linux:<MOST RECENT TAG>`. This image is a basic linux image with tools you might need, including git, curl, vim, etc. Create a new NFS volume and name it db-xscholar (e.g. new peristant volume). Mount it as:
* `/nfs` to `data`

Mount a CFS directory you want to use as a data transfer directory at `/cfs` and leave the sub-path in the volume empty. **Ensure that the "read-only" box is checked.**  There is no need to configure any other parameters for this service.

### db-admin0 configuration
Set up this node to use the docker image at `registry.nersc.gov/m3624/xscholar-vespa:<LATEST TAG>`. Under "Show advanced options > Networking", set the container's hostname to `db-admin0`. Set the `VESPA_CONFIGSERVERS` environment variable to the hostname of this service you just set, e.g. `db-admin0`. Make sure the "entrypoint" and "command" parameters under "Command" are empty. This will start both configserver and services on this node. Add the NFS volume you created during the db-admin0 configuration under "Volumes" and mount it at three directories:
* `/opt/vespa/var` to `admin0/vespa/var`
* `/opt/vespa/logs` to `admin0/vespa/logs`
* `/nfs` to `data`

This configuration will attempt to automatically load data from /nfs/feed-file.json on startup. 


### db-stateless0 configuration
Set up this node to use the docker image at `vespaengine/vespa`. Under "Show advanced options > Networking", set the container's hostname to `db-stateless0`. Set the `VESPA_CONFIGSERVERS` environment variable to the hostname of the db-admin service you previously configured, e.g. `db-admin0`. Make sure the "entrypoint" parameter under "Command" is empty, but set the "command" parameter as `services`. This will start services on this node. Add the NFS volume you created during the db-admin0 configuration under "Volumes" and mount it at two directories:
* `/opt/vespa/var` to `stateless0/vespa/var`
* `/opt/vespa/logs` to `stateless0/vespa/logs`


### db-content0 configuration
Set this node up Set up this node to use the docker image at `vespaengine/vespa`. Under "Show advanced options > Networking", set the container's hostname to `db-content0`. Set the `VESPA_CONFIGSERVERS` environment variable to the hostname of the db-admin service you previously configured, e.g. `db-admin0'. Make sure the "entrypoint" parameter under "Command" is empty, but set the "command" parameter as `services`. This will start services on this node. 
* `/opt/vespa/var` to `content0/vespa/var`
* `/opt/vespa/logs` to `content0/vespa/logs`

#### Note on adding content nodes:
For redundency/performance you can increase the number of content nodes (e.g. db-content1, db-content2, ...) See [Vespa docs](https://docs.vespa.ai/documentation/performance/sizing-search.html) to determine the setup you need. If you add more content nodes, modify [hosts.xml](https://github.com/lbnlp/xscholar-vespa/blob/main/src/main/application/hosts.xml) and [services.xml](https://github.com/lbnlp/xscholar-vespa/blob/main/src/main/application/services.xml) accordingly. 


## Starting up the Vespa cluster
The Vespa application should automatically deploy. You can verify the service is working by querying the db-stateless0 node for the application's status. 
```
$ curl --head http://db-stateless0:8080/ApplicationStatus
```
If your application is properly configured, you should recieve a `200 OK` response.

## Feeding data to Vespa
The db-admin0 node setup automatically tries to feed data from the NFS directory via "feed-file.json". You can manually feed data to your new Vespa DB though the feeding API. Create a json file in which each line is a document to be fed into the database. See [examples/data/feed-file.json](https://github.com/lbnlp/xscholar-vespa/blob/main/examples/data/feed-file.json) for an example feed file. Copy this feed file to your transfer directory on the NERSC community file system, and use the app-linux node to copy it to the NFS data directory. On the db-stateless0 node, run the following: 

```
$ java -jar /opt/vespa/lib/jars/vespa-http-client-jar-with-dependencies.jar \
    --file nfs/feed-file.json --endpoint http://db-stateless0:8080 --verbose --useCompression
```

## Query the database
On any node in your cluster, run the following: 
```
$ curl -H "Content-Type: application/json" --data '{"yql" : "select * from sources * where default contains \"thermoelectric materials\";"}' http://db-stateless0:8080/search/
```


