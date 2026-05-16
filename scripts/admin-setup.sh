# 1. Update and Install Tools
echo "=== Admin Setup Script ==="
echo "Updating system and installing git, ansible, make..."
apt update && apt upgrade -y
apt install git ansible make -y

# 2. Generate SSH Key
echo "Generating SSH key..."
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""

# 3. Output Key Information for easy copying
echo "======================================================="
echo "SSH KEY GENERATED"
echo "Location: ~/.ssh/id_ed25519"
echo "-------------------------------------------------------"
echo "PUBLIC KEY (Copy this to your other VMs/LXCs):"
echo ""
cat ~/.ssh/id_ed25519.pub
echo ""
echo "======================================================="

# 4. Clone the Lab Repository
echo "Cloning homelab repository"
git clone https://github.com/aaronschm/homelab.git

# 5. Run the hardening script (located inside the cloned repo)
echo "Starting SSH hardening..."
if [ -f ~/homelab/scripts/ssh-setup.sh ]; then
    echo "Running ssh-setup.sh"
    bash ~/homelab/scripts/ssh-setup.sh
else
    echo "Error: ssh-setup.sh not found in repo!"
fi
cd homelab