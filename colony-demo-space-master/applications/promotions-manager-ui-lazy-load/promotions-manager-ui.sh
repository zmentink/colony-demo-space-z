#!/bin/bash
echo '=============== Staring init script for Promotions Manager UI ==============='

# save all env for debugging
printenv > /var/log/colony-vars-"$(basename "$BASH_SOURCE" .sh)".txt

echo '==> Installing Node.js and NPM'
apt-get update
apt install curl -y
curl -sL https://deb.nodesource.com/setup_10.x | bash -
apt install nodejs

echo '==> Install nginx'
apt-get install nginx -y

####################  lazy load artifact ####################

# install aws cli
apt install awscli -y

# consts
wait_sec=45 # 20 minutes
wait_interval=15 # not recommended to set a lower interval in order to avoid aws api throttling

echo "Trying to download artifacts file: s3://$ARTIFACT_BUCKET/$ARTIFACT_KEY"

# get the file name from the artifact key
file_name="$(basename $ARTIFACT_KEY)"

for (( c=0 ; c<$wait_sec ; c=c+$wait_interval ))
do
		# safely check if file exists in s3
        aws s3api head-object --bucket "$ARTIFACT_BUCKET" --key "$ARTIFACT_KEY" || not_exists="yes"

        if [[ "$not_exists" == "yes" ]]
        then
                let remaining=$wait_sec-$c
                echo "File $ARTIFACT_BUCKET/$ARTIFACT_KEY not found, waiting $wait_interval sec. Remaining timeout is $remaining seconds."
				# reset the $not_exists var
                unset not_exists
        else
                echo "File found, downloading file to current dir"
                aws s3api get-object --bucket "$ARTIFACT_BUCKET" --key "$ARTIFACT_KEY" "$file_name"
				file_downloaded=true
                break
        fi

        sleep $wait_interval
done

# check if timeout reached
if [ ! $file_downloaded ]
then
	echo "Timeout reached, no artifact available, exiting with error"
	exit 1
fi

################################################################

echo '==> Extract ui artifact to /var/www/promotions-manager/'
mkdir ./drop
tar -xvf ./$file_name -C ./drop/
mkdir /var/www/promotions-manager/
tar -xvf ./drop/drop/promotions-manager-ui.*.tar.gz -C /var/www/promotions-manager/

echo '==> Configure nginx'
cd /etc/nginx/sites-available/
cp default default.backup

cat << EOF > ./default
server {
	listen $PORT default_server;
	listen [::]:$PORT default_server;
	root /var/www/promotions-manager;
	server_name _;
	index index.html index.htm;
	location /api {		
		proxy_pass http://promotions-manager-api.$DOMAIN_NAME:$API_PORT/api;
		proxy_http_version 1.1;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection 'upgrade';
		proxy_set_header Host \$host;
		proxy_cache_bypass \$http_upgrade;
		proxy_read_timeout 600s;
	}
	location / {
		try_files \$uri /index.html;
	}
}
EOF