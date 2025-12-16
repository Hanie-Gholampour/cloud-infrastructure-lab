# VCC Project 2025-2026

Welcome to the VCC Project 2025-2026 repository.


Look for `TODO` tags throughout the repository to identify the tasks you need to complete.  
We recommend using a code editor extension such as **TODO Tree** (VS Code) (<https://marketplace.visualstudio.com/items?itemName=Gruntfuggly.todo-tree>)  to quickly locate and navigate all TODO entries across the project.

## Usage

The **Vagrantfile** contains several configuration variables that should be adjusted according to your environment.  
In particular, you may need to modify:

- **`provider`** — the virtualization backend you want to use (`virtualbox`, `vmware_desktop`, `libvirt`)

- **`KEY_FILE_PATH`** — the path to your own public SSH key, which will be uploaded to all VMs

- **`RAM_SIZE`**, **`CPU_COUNT`**, **`CONTROL_RAM_SIZE`**, **`CONTROL_CPU_COUNT`** — the amount of RAM and CPU to allocate to the control node and the worker nodes, based on the resources available on your host machine.

From *your host machine* you can use:

- `vagrant up` to start the VCC virtual machines  

- `vagrant destroy -f` to remove them  

- `vagrant ssh control` to access the VCC control node  

- `vagrant ssh node1` to access the first VCC worker node  

- `vagrant ssh node2` to access the second VCC worker node  

We recommend creating a snapshot after the initial setup, for example: `vagrant snapshot create <node> clean`.
This allows you to quickly restore a *clean* state at any time using `vagrant snapshot restore <node> clean` avoiding the need to re-orchestrate the entire environment from scratch.

*Inside the control node*, the playbook is available in the `/vagrant` directory.  
From there, you can use the `make` command to perform the following operations:

- `python-setup`: initialize the Ansible environment on the control node.  
  **Run this as the very first step after bootstrapping the control node.**

- `ping`: verify that Ansible can reach all nodes

- `setup-all` (default): execute the full Ansible playbook.  
  **This target runs when you simply execute `make` with no arguments.**

- `registry`: install only the local Docker registry

- `images`: rebuild Docker images and push them to the local registry

- `deploy`: rebuild Docker images and deploy the complete VCC stack

- `services`: deploy only the VCC stack (without rebuilding images)

- `update`: update configuration files and apply stack changes  
  *(use `docker service update --force vcc_[servicename]` to manually restart a single service)*

After the orchestration completes, two Docker Swarm stacks are deployed automatically:

- **`registry`** — provides the shared local Docker registry used by all nodes  
- **`vcc`** — runs the full VCC project stack.

## DNS names

**Remember: to access the project websites from your local browser, you must add host aliases on your host machine, pointing to the Virtual IP address `192.168.255.100`.**
