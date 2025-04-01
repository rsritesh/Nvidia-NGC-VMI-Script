# Nvidia-NGC-VMI-Script
Installation script to make a Cloud VM  as NVIDIA GPU-Optimized VMI

For many envoirnements such as public clouds and private clouds, when a user have standard cloud virtual machine images (VMI), this repository provides setup script to install NVIDIA NGC VMI requirements such as GPU driver, Docker and NVIDIA container toolkit. After installation of this script, virtual machine image can be used for accelerating your Machine Learning, Deep Learning, Data Science and HPC workloads aviailable on the NVIDIA NGC Portal.
NVIDIA NGC Portal  provides  access to containerized AI, Data Science, and HPC applications, pre-trained models, AI SDKs and other resources.

This is script is tested only on Ubuntu Server 22.04 LTS (x86) and, by default, installs following drivers and packages
      NVIDIA TRD Driver (550.127.05)
      Docker CE (27.3.1)
      NVIDIA Container Toolkit (latest version)
      NGC CLI (latest version)
      JupyterLab (latest version) and core Jupyter packages
      Miniconda (latest version)
      Git, Python3, and pip
