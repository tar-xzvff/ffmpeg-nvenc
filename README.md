# ffmpeg-nvenc

NVIDIA GPU(nvenc) を用いてHW動画エンコードを行うDockerコンテナ

参考: https://qiita.com/yamakenjp/items/7474f210efd82bb28490

## build
```shell
git clone https://github.com/tar-xzvff/ffmpeg-nvenc.git
cd ffmpeg-nvenc
docker build -t ffmpeg-nvenc .
```

## run
```shell
docker run --gpus all -e NVIDIA_DRIVER_CAPABILITIES=video -it ffmpeg-nvenc ffmpeg
```