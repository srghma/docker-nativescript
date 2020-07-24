up:
	docker-compose up --build

docker-build:
	docker build -f Dockerfile -t docker-nativescript:0.0.2 .
