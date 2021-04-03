FROM public.ecr.aws/o8l5c1i1/swift:5.3.2-amazonlinux2 as build
RUN yum makecache fast
RUN yum -y install ImageMagick ImageMagick-devel

WORKDIR /src
COPY . .
RUN swift build --product RecognitionFunction -c release -Xswiftc -static-stdlib

FROM public.ecr.aws/lambda/provided:al2
COPY --from=build /src/.build/release/RecognitionFunction /main
ENTRYPOINT [ "/main" ]
