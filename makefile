include .env

drun:
	docker run -it --rm zenn:0.3 /bin/bash
	
preview:
	docker run -it --rm -p 8888:8000 zenn:0.3 npx zenn preview
	