
build:
	hugo --cleanDestinationDir -d docs
	echo "blog.fengxu.im" > docs/CNAME
