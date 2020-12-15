# Installing Operators Using the OLM

In order to understand how OLM works we first needs to be a client of OLM.
for this exercise we will login to our running cluster and install an Operator 
from our prebuild custom OLM.

## Operator Selection

On the OpenShift web Console, login as Cluster Admin and browse to:
**Operators** --> **OperatorHUb**. Scroll to the operator that you would like to install:
![OperatorHub Operator Selection](images/operator-gui1.png)
## Operator Details
View the details of the operator including it Capability Level. Press **Install** to continue:
![Operator Install](images/operator-gui2.png)
## Operator Installation Options
Enter/modify the operator's arguments and press **Install**:
![Install Operator](images/operator-gui3.png)
## Wait for Success
Browse to **Operators**->**Installed Operators** and wait for **Success**.
![Sucess](images/operator-gui4.png)
# Instantiating an Instance from the Operator
Log in to the OpenShift console as a developer and browse to "+Add"->"From Catalog":
![From Catalog](images/operator-gui5.png)
## Search for the Operator
Search for the Jenkins operator and select it:
![Jenkins Operator](images/operator-gui6.png)
## Create the Operator
![Create the Operator](images/operator-gui7.png)
## Provide a Unique Name
Provide a unique name and configure settings. Then scroll to the bottom and press **Create**:
![Create](images/operator-gui8.png)
Wait for the instance to be created and start using it.