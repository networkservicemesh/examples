package ipreceiver

//go:generate bash -c "protoc -I.  --proto_path=$GOPATH/src/ --go_out=plugins=grpc:. *.proto"
