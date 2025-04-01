#!/bin/bash

# Default values
COMMAND=""
DRIVER_VERSION="550.127.05"
DOCKER_CE_VERSION="27.3.1"
CUDA_VERSION=""


# Function to display help information
show_help() {
    echo "Usage: $0 --install --nvdriver DRIVER_VERSION --dockerce DOCKER_CE_VERSION"
    echo "       $0 --uninstall"
    echo ""
    echo "Options:"
    echo "  --install            Install NVIDIA drivers, CUDA, Docker, Miniconda, Jupyter, and NGC CLI"
    echo "  --uninstall          Uninstall all installed components"
    echo "  --nvdriver DRIVER_VERSION   Specify the NVIDIA driver version (default is $DRIVER_VERSION)"
    echo "  --dockerce DOCKER_CE_VERSION   Specify the Docker CE version (default is $DOCKER_CE_VERSION)"
#   echo "  --cudaversion CUDA_VERSION  Specify the CUDA version (e.g., 12.4) (required for --install)"
    echo "  -h                   Display this help message"
    exit 0
}

# Function to install all pacakges
install_all() {
  
    # Parse command line arguments
    while getopts "nvdriver:dockerce:" opt; do
      case $opt in
        nvdriver) DRIVER_VERSION="$OPTARG" ;;
        dockerce) DOCKER_CE_VERSION="$OPTARG" ;;
	*) echo "Usage: $0 --nvdriver DRIVER_VERSION --dockerce DOCKER_CE_VERSION" >&2
           exit 1 ;;
      esac
    done
    echo "Debug: --nvdriver $DRIVER_VERSION --dockerce $DOCKER_CE_VERSION"
    # Check if required arguments are provided
    if [ -z "$DRIVER_VERSION" ] || [ -z "$DOCKER_CE_VERSION" ]; then
      echo "Error: Both DRIVER_VERSION and DOCKER_CE_VERSION are required."
      echo "Usage: $0 --nvdriver DRIVER_VERSION --dockerce DOCKER_CE_VERSION"
      exit 1
    fi

    echo "Info: Installing all packages..."	
    
	# disable "Pending kernel upgrade" Interactive notifications 
	# https://askubuntu.com/questions/1349884/how-to-disable-pending-kernel-upgrade-message
	sudo sed -i "s/#\$nrconf{kernelhints} = -1;/\$nrconf{kernelhints} = -1;/g" /etc/needrestart/needrestart.conf
	# https://www.faqforge.com/linux/fixed-ubuntu-apt-get-upgrade-auto-restart-services/ 
	sudo sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf

    # Update system packages
    #sudo apt update && sudo apt upgrade -y
	#sudo apt update && sudo apt dist-upgrade -y

    # Install necessary dependencies
    sudo apt install -y build-essential gcc linux-headers-$(uname -r) wget

    # Download and install NVIDIA GPU driver
    wget https://us.download.nvidia.com/XFree86/Linux-x86_64/${DRIVER_VERSION}/NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run
    chmod +x NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run
    sudo ./NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run --silent --dkms --no-questions --ui=none --no-questions

    # Verification of Nvidia Driver with smi
    if [ nvidia-smi --query-gpu=name --format=csv,noheader | wc -l  == 0 ]; then
	  nvidia-smi -L | grep -q "GPU" && echo "NVIDIA GPU(s) detected" || echo "No NVIDIA GPU detected"
	  echo "Error: No GPU's are detected, please check if this flavor of VM has GPUs"
      exit 1
	fi
	nvidia-smi -L | grep -q "GPU" && echo "NVIDIA GPU(s) detected" || echo "No NVIDIA GPU detected"
	# Get the current NVIDIA driver version
	CURRENT_DRIVER_VERSION=$(modinfo nvidia | grep ^version | awk '{print $2}')

	# Check if the current driver version matches the desired version
	if [[ "$CURRENT_DRIVER_VERSION" == "$DRIVER_VERSION" ]]; then
      echo "Info: Current NVIDIA driver version ($CURRENT_DRIVER_VERSION) matches the desired version"
	else
      echo "Error: Current NVIDIA driver version ($CURRENT_DRIVER_VERSION) does not match the desired version ($DRIVER_VERSION)"
	  exit 1
	fi
		

    # Install CUDA toolkit
    #wget https://developer.download.nvidia.com/compute/cuda/${CUDA_VERSION}/local_installers/cuda_${CUDA_VERSION}_linux.run
    #sudo sh cuda_${CUDA_VERSION}_linux.run --silent --toolkit


    # Install Docker
    sudo apt update
    sudo apt install apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    apt-cache madison docker-ce
    sudo apt-get install -y  docker-ce=5:${DOCKER_CE_VERSION}-1~ubuntu.$(lsb_release -rs)~$(lsb_release -cs)
    # sudo apt install -y docker.io
    sudo usermod -aG docker $USER
    docker info


    # Install NVIDIA Container Toolkit
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    sudo apt update && sudo apt install -y nvidia-container-toolkit

    #Configure the container runtime by using the nvidia-ctk command
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker

    # Install NGC CLI
    wget -O ngccli_linux.zip https://ngc.nvidia.com/downloads/ngccli_linux.zip && unzip -o ngccli_linux.zip && chmod u+x ngc-cli/ngc
    echo 'export PATH="$PATH:$HOME/ngc-cli"' >> ~/.bashrc
    rm ngccli_linux.zip


    sudo apt install python3 -y 
    sudo apt install python3-pip -y

    # Install Miniconda
    MINICONDA_VERSION="Miniconda3-latest-Linux-x86_64.sh"
    wget https://repo.anaconda.com/miniconda/${MINICONDA_VERSION}
    bash ${MINICONDA_VERSION} -b -p $HOME/miniconda
    rm ${MINICONDA_VERSION}
    echo 'export PATH="$HOME/miniconda/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc

    # Install Jupyter
    sudo pip install jupyterlab
    export PATH="$HOME/.local/bin:$PATH"

    # Enable persistence mode
    sudo nvidia-smi -pm 1

    echo "NVIDIA GPU environment setup complete. Please reboot your system and run 'source ~/.bashrc' after reboot."



}

# Function to uninstall all packages
uninstall_all() {
    echo "Uninstalling all packages..."

    # Remove NVIDIA GPU driver
    sudo nvidia-uninstall

    # Remove CUDA toolkit
    # sudo /usr/local/cuda/bin/cuda-uninstaller

    # Remove NVIDIA Container Toolkit
    sudo apt remove -y nvidia-container-toolkit
    sudo apt autoremove -y
    sudo apt-get remove --purge '^nvidia-.*' -y
	
	docker stop $(docker ps -aq)
    docker system prune -a --volumes
    sudo systemctl stop docker
    sudo apt-get purge docker-ce docker-ce-cli containerd.io -y
    sudo rm -rf /etc/docker
    sudo rm -rf /var/lib/docker
    sudo groupdel docker
    sudo rm -rf /var/run/docker.sock
    sudo rm -rf ~/.docker
    sudo apt-get autoremove -y docker.io
	
	if command -v docker &> /dev/null; then
	  docker_version=$(docker --version | awk '{print $3}' | sed 's/,//')
      echo "Error: Docker is installed. Version: $docker_version. Please remove manually"
	else
      echo "Info: Docker is uninstalled"
	fi


    # Remove Miniconda
    rm -rf $HOME/miniconda
	rm -rf $HOME/.condarc $HOME/.conda


    # Remove NGC CLI
    rm -rf $HOME/ngc-cli
	
	# Remove jupyterlab
	sudo pip uninstall jupyterlab -y

    # Remove added PATH entries from .bashrc
    sed -i '/miniconda/d' ~/.bashrc
    sed -i '/ngc-cli/d' ~/.bashrc

    echo "Uninstallation complete. Please reboot your system."
}

# Main script logic to handle command-line arguments
if [[ $# -eq 0 ]]; then
  show_help
fi

# Parse command-line arguments using flags and options
while [[ $# -gt 0 ]]; do
  case "$1" in
      --install)
          COMMAND="install"
          shift ;;
      --uninstall)
          COMMAND="uninstall"
          shift ;;
      --nvdriver)
          DRIVER_VERSION="$2"
          shift 2 ;;
      --dockerce) 
	  DOCKER_CE_VERSION="$2"
	  shift 2 ;; 
#     -c)
#         CUDA_VERSION="$2"
#         shift 2 ;;
      -h|--help)
          show_help ;;
      *)
          echo "Unknown option: $1"
          show_help ;;
  esac
done

# Execute the appropriate function based on the command provided by the user.
if [[ "$COMMAND" == "install" ]]; then
  install_all

elif [[ "$COMMAND" == "uninstall" ]]; then
  uninstall_all

else
  echo "Error: Invalid command. Use --install or --uninstall."
  show_help
fi
