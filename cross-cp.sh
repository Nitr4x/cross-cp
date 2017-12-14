#!/bin/bash

function check_requirements {
    echo "+ Checking requirements"

    if hash docker 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

function check_compiler {
    echo "+ Checking compiler type"

    case "$1" in
        gcc)
            return 0
            ;;
        g++)
            return 0
            ;;
        *)
            echo "- Cannot compile" >&2
            exit -1
            ;;
    esac
}

function check_args {
    if [ $# -eq 0 ]; then
        usage
        exit -1
    fi

    i=2
    while getopts ":a:c:f:s:" opt; do
        case $opt in
            a)
                arch=$OPTARG
                ;;
            c)
                compiler=$OPTARG
                ;;
            f)
                files=${@:$i:5}
                ;;
            s)
                os=$OPTARG
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                usage
                exit -1
                ;;
            :)
                echo "Option -$OPTARG requires an argument." >&2
                usage
                exit -1
                ;;
        esac
        ((i=i+2))
    done

    echo 'arch="$arch"; compiler="$compiler"; os="$os"; files="$files"' > /dev/null
}

function usage {
    echo -e "\nUsage: ./cross-cp.sh -s [debian|ubuntu|...] -a [64|32] -c [gcc|g++] -f [FILES,...]\n"
    echo -e "\t -s: Operating system"
    echo -e "\t -a: system architecture"
    echo -e "\t -c: compiler"
    echo -e "\t -f: files to compile\n"
}

function welcome {
    echo "
    ██████╗██████╗  ██████╗ ███████╗███████╗       ██████╗██████╗
   ██╔════╝██╔══██╗██╔═══██╗██╔════╝██╔════╝      ██╔════╝██╔══██╗
   ██║     ██████╔╝██║   ██║███████╗███████╗█████╗██║     ██████╔╝
   ██║     ██╔══██╗██║   ██║╚════██║╚════██║╚════╝██║     ██╔═══╝
   ╚██████╗██║  ██║╚██████╔╝███████║███████║      ╚██████╗██║
    ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝       ╚═════╝╚═╝

    This script aims to provide an efficient way to compile source
    code for a given architecture.
    Created and maintained by Nitrax - <nitrax@lokisec.fr>
    "
}

function dockerfile_generation {
    echo "+ Generating dockerfile"

    if [ $2 -eq 32 ]; then
        echo "FROM $2bit/$1" > Dockerfile
    else
        echo "FROM $1" > Dockerfile
    fi

echo "RUN apt update" >> Dockerfile
    echo "RUN apt -y install gcc g++" >> Dockerfile
    echo "VOLUME /tmp/data" >> Dockerfile

    for file in $files; do
        echo "ADD $file /tmp/data/" >> Dockerfile
    done

    echo "WORKDIR /tmp/data" >> Dockerfile
    echo 'CMD ["/bin/bash"]' >> Dockerfile
}

function docker_build {
    echo "+ Building container"

    sudo docker build -t cross-cp .
}

function docker_run {
    echo "+ Running docker container"

    sudo docker run -td -v $PWD/bin:/tmp/data/bin --name cross-cp cross-cp
}

function compile {
    echo "+ Compiling payload"

    sudo docker exec cross-cp $1 $2 -o bin/exploit
}

function cleanup {
    echo "+ Cleaning container"

    sudo docker stop cross-cp > /dev/null
    sudo docker rm cross-cp > /dev/null
    rm Dockerfile
}

# Core script

eval check_args $@

welcome

check_requirements
check_compiler $compiler

if [ $? -eq 0 ]; then
    dockerfile_generation $os $arch $compiler $files
    docker_build
    docker_run
    compile $compiler $files
    cleanup
else
    echo "Docker must be installed [https://www.docker.com/]"
    exit -1
fi
