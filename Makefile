up:
	docker-compose up --build

# docker build --no-cache -f Dockerfile -t docker-nativescript:0.0.2 .
docker-build:
	docker build -f Dockerfile -t docker-nativescript:0.0.2 .
