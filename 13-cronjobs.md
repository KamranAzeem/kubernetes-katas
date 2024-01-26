# cronjob:

Cron jobs are tasks that are run repeatedly, at a certain time of the day, with certain frequency, independent of any running applications in the cluster . Examples of these tasks are:

* Backup of databases to a remote location
* Clean up of logs of some database server or some other application
* etc,

The Kubernetes cronjob works in the same way as unix/linux cron, using the same syntax for specifying the actual schedule. 


This chapter will use an example to help explain the concepts. 

Consider a situation where you have a MySQL database that you want to take backup of everyday at `19:00` hours. You also want to put this backup at a remote location in some S3 compatible bucket, such as AWS S3, GCS, or minio, etc.

For this to work, you need the following:

* Credentials to MySQL database, including the host, the port, dbname, db-user and db-password. This will go in a kubernetes secret.
* Credentials to S3 bucket, including the URL, the name of the bucket and access keys. This will go into a secret.
* A backup script or a command to perform the mysql backup, which means a container image with mysql in it. A script can be loaded as a configmap. The `mysql-dump` binary needs to be part of the container image.
* A S3 CLI /script and a commad to put that database backup on the remote S3 location. This means a container with AWS CLI , or some S3 cli software in it.
* Schedule, which is going to be: everyday at `19:00` hours. This will be written as `0 19 */1 * *`

 
Mysql dump command:

```
export RESULT_FILE=/tmp/$(date +F)-${MYSQLDBNAME}-compressed-mysql.dump

mysqldump \
  --compress \
  --routines \
  --host=${MYSQLHOST} \
  --port=${MYSQLPORT} \
  --user=${MYSQLUSER} \
  --password=${MYSQLPASSWORD} \
  --databases ${MYSQLDBNAME} \
  --result-file=/tmp/$(date +%F)-${MYSQLDBNAME}-compressed-mysql.dump
```

S3 command:
```
gsutil sync ${RESULT_FILE} ${GCSBUCKETNAME}/${RESULT_FILE}

```


## Create configmaps and secrets:


## Create the main cronjob:


## Verify:




