# Installing Wireshark and Creating Capture Profiles for UDP and TCP Analysis

This document guides you through the process of installing Wireshark, a powerful network protocol analyzer, and setting up two distinct capture profiles: one specifically for UDP traffic and another for TCP traffic. We will also cover the basics of creating capture filters and coloring rules to enhance your network analysis workflow.

## Step 1: Installing Wireshark

The installation process for Wireshark varies depending on your operating system. Here are the common methods:

### On Windows:

1.  **Navigate to the Wireshark Download Page:** Open your web browser and go to the official Wireshark website: [https://www.wireshark.org/download.html](https://www.wireshark.org/download.html)
2.  **Download the Installer:** Under the "Stable Release" section, find the appropriate installer for your Windows version (32-bit or 64-bit) and download it.
3.  **Run the Installer:** Double-click the downloaded `.exe` file to start the installation wizard.
4.  **Follow the On-Screen Instructions:**
    * Carefully read and accept the license agreement.
    * Choose the components you want to install. It's generally recommended to install all default components, including TShark (the command-line version of Wireshark).
    * You might be prompted to install **Npcap**, a packet capture library for Windows. **It is highly recommended to install Npcap** as Wireshark relies on it for capturing network traffic. Follow the Npcap installer prompts as well.
    * Continue through the installation process, accepting the default installation locations unless you have a specific reason to change them.
5.  **Complete the Installation:** Once the installation is finished, you can find Wireshark in your Start Menu.

### On macOS:

1.  **Navigate to the Wireshark Download Page:** Open your web browser and go to the official Wireshark website: [https://www.wireshark.org/download.html](https://www.wireshark.org/download.html)
2.  **Download the DMG:** Under the "Stable Release" section, download the `.dmg` file for macOS.
3.  **Open the DMG:** Double-click the downloaded `.dmg` file to mount the Wireshark disk image.
4.  **Drag and Drop:** Drag the Wireshark application icon to your "Applications" folder.
5.  **Install ChmodBPF (Optional but Recommended):** For non-administrator users to capture packets without using `sudo`, you might need to install `ChmodBPF`. The Wireshark DMG often includes an installer for this. Run it if available and follow the prompts. Alternatively, you can find instructions on the Wireshark website.

### On Linux (Fedora/CentOS/RHEL):

1.  **Open your Terminal:**
2.  **Install Wireshark:** Run the command: `sudo dnf install wireshark` or `sudo yum install wireshark` depending on your distribution.
3.  **Configure Permissions (Important):** You might need to grant your user the necessary permissions to capture packets. This often involves adding your user to a specific group (like `wireshark`) and potentially configuring `setcap`. Consult your distribution's documentation for the recommended approach.

## Step 2: Creating Capture Profiles

Capture profiles allow you to save specific Wireshark settings, including interface selection and capture filters. We will create two profiles: one for UDP and one for TCP.

1.  **Open Wireshark:** Launch the Wireshark application.
2.  **Access Capture Options:** On the welcome screen, click on the interface you want to capture traffic from, or go to **Capture > Options...** (or use the shortcut `Ctrl+K` or `Cmd+K`).
3.  **Create a New Profile:** In the "Capture Options" window, click the **"Manage Profiles..."** button (usually located next to the "Start" button).
4.  **Add a New Profile:** In the "Profiles" window, click the **"+"** (Add) button.
5.  **Name the UDP Profile:** Enter a descriptive name for your UDP profile, for example, "Capture UDP Traffic". Click **"OK"**.
6.  **Configure the UDP Profile:**
    * Ensure the correct interface is selected under the "Interface" section.
    * In the "Capture Filter" section, enter `udp`. This filter will instruct Wireshark to only capture packets using the User Datagram Protocol.
    * Click **"OK"** to save the UDP profile.
7.  **Create a New Profile for TCP:** Repeat steps 3 and 4.
8.  **Name the TCP Profile:** Enter a name like "Capture TCP Traffic" and click **"OK"**.
9.  **Configure the TCP Profile:**
    * Again, ensure the correct interface is selected.
    * In the "Capture Filter" section, enter `tcp`. This filter will capture only Transmission Control Protocol packets.
    * Click **"OK"** to save the TCP profile.
10. **Close the Profiles Window:** Click **"Close"** in the "Profiles" window.

Now, in the main Wireshark window, you can select your desired profile from the dropdown menu next to the capture interface list before starting a capture.

## Step 3: Understanding and Creating Capture Filters

Capture filters are powerful tools that allow you to specify which network traffic Wireshark should capture. This helps in focusing on relevant data and reducing the size of the capture file.

**Basic Syntax:**

Capture filters use a specific syntax based on the `libpcap` filter expression language. Here are some common examples:

* **Protocol-based:**
    * `tcp`: Capture only TCP traffic.
    * `udp`: Capture only UDP traffic.
    * `icmp`: Capture only ICMP (ping) traffic.
    * `arp`: Capture only ARP traffic.
    * `http`: Capture traffic on the standard HTTP port (port 80).
    * `dns`: Capture DNS traffic (port 53).

* **Host-based:**
    * `host 192.168.1.100`: Capture traffic to or from the IP address 192.168.1.100.
    * `src host 192.168.1.100`: Capture traffic originating from 192.168.1.100.
    * `dst host 192.168.1.100`: Capture traffic destined for 192.168.1.100.

* **Port-based:**
    * `port 80`: Capture traffic on port 80 (source or destination).
    * `src port 53`: Capture traffic with a source port of 53 (DNS requests).
    * `dst port 443`: Capture traffic with a destination port of 443 (HTTPS).

* **Combining Filters:** You can combine filters using logical operators:
    * `and` or `&&`: Both conditions must be true (e.g., `tcp and host 192.168.1.100`).
    * `or` or `||`: Either condition can be true (e.g., `tcp or udp`).
    * `not` or `!`: Negates the condition (e.g., `not arp`).

**Applying Capture Filters:**

You apply capture filters in the "Capture Filter" field within the "Capture Options" window when starting a new capture or when editing a capture profile.

## Step 4: Understanding and Creating Coloring Rules

Coloring rules in Wireshark allow you to visually highlight packets based on specific criteria. This can significantly improve your ability to identify and analyze relevant traffic.

1.  **Access Coloring Rules:** Go to **View > Coloring Rules...**
2.  **Create a New Coloring Rule:** Click the **"+"** (Add new coloring rule) button.
3.  **Name the Rule:** Enter a descriptive name for your rule. For example, "Highlight UDP" or "Highlight TCP Errors".
4.  **Set the Filter:** In the "Filter" column, enter a display filter expression that defines the packets you want to color. Display filters use a slightly different syntax than capture filters and are applied to already captured data.
    * **For UDP highlighting:** Enter `udp`.
    * **For TCP error highlighting (e.g., retransmissions):** Enter `tcp.analysis.retransmission`.
    * **For highlighting traffic to a specific IP:** Enter `ip.dst == 192.168.1.100`.
    * **For highlighting traffic on a specific port:** Enter `tcp.port == 80` or `udp.port == 53`.
5.  **Choose a Color:** Click on the "Color" box for your new rule. A color selection dialog will appear, allowing you to choose the background and foreground colors for the highlighted packets. Select a color that stands out.
6.  **Save the Rule:** Click **"OK"** in the "Edit Color Rule" dialog.
7.  **Apply and Manage Rules:** In the "Coloring Rules" window, you can:
    * **Enable/Disable Rules:** Check or uncheck the box next to a rule to activate or deactivate it.
    * **Change Rule Order:** Use the "Up" and "Down" buttons to adjust the order of rules. Rules are evaluated from top to bottom, and the first matching rule's color is applied.
    * **Edit Rules:** Select a rule and click the "Edit" button to modify its filter or color.
    * **Delete Rules:** Select a rule and click the "-" (Delete) button to remove it.
8.  **Close the Coloring Rules Window:** Click **"OK"**.

Now, when you capture or open a capture file, packets matching your defined coloring rules will be highlighted according to the colors you selected, making it easier to visually identify specific types of traffic or network events.

By following these steps, you can effectively install Wireshark, create dedicated capture profiles for UDP and TCP analysis, and utilize the power of capture filters and coloring rules to streamline your network troubleshooting efforts. Remember to consult the official Wireshark documentation for more advanced filtering and coloring options.
