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

## Create a GCS user service account and a GCS bucket:
GCS buckets are S3 compatible.

Create a service account in GCP -> IAM, with permissions for the role "cloud storage admin". Then, download it's json key. Save this key as `gcp-key.json`

Then create a bucket in GCS with a unique name. Use GCP -> Cloud Storage -> Buckets .

## Setup a simple/example mysql service as a stateful set:

This is a very simple example, so most of the secrets are just stored in the YAML file as plain text secrets.

```
kubectl apply -f mysql-statefulset.yaml
```

Once the mysql pod is running, create a simple database inside it, by exec into it. 

On the `mysql` prompt:

```
$ kubectl exec -it mysql-0 -- bash

root@mysql-0:/# mysql  -u root -p${MYSQL_ROOT_PASSWORD}

MariaDB [(none)]> 
```

, run the following commands.

```
create user 'wordpress'@'%' identified by  'wordpress';

GRANT all PRIVILEGEs ON wordpress.* TO 'wordpress'@'%';
flush privileges;

insert into wp_users values(1,'kamran');

insert into wp_users values(2,'john');

insert into wp_users values(1,'david');
```

## Create configmaps and secrets:

Create a secret with this key:

```
kubectl create secret generic gcp-key-json \
        --from-file=./gcp-key.json
```

Create a configmap out of the shell script.

```
kubectl create configmap mysql-backup-script  \
  --from-file ./mysql-dump-to-gcs.sh
```


## Create a test pod replicating the cronjob:
This will help setup the job as you want to. Using a test pod is a good idea.

```
kubectl apply -f mysql-pg-gsutil.yaml
```

Exec into this container/pod and run the script manually. See that it works.

```
$ kubectl exec -it mysql-pg-gsutil -- bash

bash-5.1# /root/mysql-dump-to-gcs.sh 

Starting backup of wordpress to /tmp/2024-01-26-16-03-wordpress-compressed-mysql.dump ...
Backup of MySQL database wordpress to /tmp/2024-01-26-16-03-wordpress-compressed-mysql.dump .. Done.
-rw-r--r--    1 root     root        2.2K Jan 26 16:03 /tmp/2024-01-26-16-03-wordpress-compressed-mysql.dump

Activated service account credentials for: [sa-training-session@trainingvideos.iam.gserviceaccount.com]

Copying file:///tmp/2024-01-26-16-03-wordpress-compressed-mysql.dump [Content-Type=application/octet-stream]...
/ [1 files][  2.2 KiB/  2.2 KiB]                                                
Operation completed over 1 objects/2.2 KiB.                                      

Backup to gs://mysql-backups-aclab-me//tmp/2024-01-26-16-03-wordpress-compressed-mysql.dump .. Done.

gs://mysql-backups-aclab-me/2024-01-26-16-03-wordpress-compressed-mysql.dump
```

Once it is verified that it works, you can now run the actual cronjob:
       
        
## Create the main cronjob:

```
$ kubectl apply -f cronjob.yaml
```



## Verify:


```
$ kubectl get cronjobs

NAME                     SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
mysql-db-backup-to-gcs   */2 * * * *   False     1        1s              7s
```

```
$ kubectl get jobs -w

NAME                              COMPLETIONS   DURATION   AGE
mysql-db-backup-to-gcs-28438088   0/1           3s         3s
```




