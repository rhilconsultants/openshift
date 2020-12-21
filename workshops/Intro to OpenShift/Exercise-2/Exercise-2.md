# Exercise 2 - Introduction to OpenShift Console

## Contents

  * To create a sample application
  * Adding health checks to your sample application
  * Monitoring your sample application

### Getting started with a sample

#### Creating a sample application


1. Using the perspective switcher at the top of the navigation, go to </> Developer.

2. Go to the +Add page in the navigation.

3. Using the project drop-down list, select the project you would like to create the sample application in. You can also create a new one if you’d like.

4. Click Samples to create an application from a code sample.

5. Click on the Node.js card.

6. Scroll down and click Create.

The Topology view will load with your new sample application. The application is represented by the light grey area with the white border. The deployment is a white circle.

**Check your work**

To verify the application was successfully created:

1. Do you see a sample-app application?

2. Do you see a nodejs-sample deployment?

#### view the build status

##### To view the build status of the sample application:

1. Hover over the icon on the bottom left quadrant of the nodejs-sample deployment to see the build status in a tooltip.

2. Click on the icon for quick access to the build log.

You should be able to see the log stream of the nodejs-sample-1 build on the Build Details page.

**Check your work**

To verify the build is complete:

Wait for the build to complete. It may take a few minutes. Do you see a Completed badge on the page header?

#### viewing the associated Git Repo

##### To view the associated code:

1. If you aren't already there, go to the Topology page in the navigation.

2. The icon on the bottom right quadrant of the nodejs-sample deployment represents the Git repo of the associated code. The icon shown can be for Bitbucket, GitHub, GitLab or generic Git. Click on it to navigate to the associated Git repository.

#### viewing the pod status

##### To view the pod status:

1. Click on the browser tab with OpenShift. Notice that the nodejs-sample deployment has a pod donut imposed on the circle, representing the pod status

2. Hover over the pod donut.

You should now see the pod status in a tooltip.

**Check your work**

To verify you see the pod status:

Do you see the number of associated pods and their statuses?

#### running the sample application

##### To run the sample application:

1. The icon on the top right quadrant of the nodejs-sample deployment represents the route URL. Click on it to open the URL and run the application.

The application will be run in a new tab.

**Check your work**

To verify your sample application is running:

1. Make sure you are in the new tab.

2. Does the page have a Welcome to your Node.js application on OpenShift title?

Your sample application is deployed and ready! 
Next we will see how To add health checks to your sample app.

### Adding health checks to your sample application 

#### health checks to your sample application.

You should have previously created the sample-app application and nodejs-sample deployment using the Get started with a sample quick start. If you haven't, you may be able to follow these tasks with any existing deployment without configured health checks.

##### To view the details application:

1. Go to the project your sample application was created in.

2. In the </> Developer perspective, go to Topology.

3. Click on the nodejs-sample deployment to view its details.

A side panel is displayed containing the details of your sample application.

**Check your work**

To verify you are viewing the details of your sample application:

Is the side panel titled nodejs-sample?

To verify that there your sample application has no health checks configured:

1. View the information in the Resources tab in the side panel.


##### To add health checks to your sample:


1. Add health checks to your nodejs-sample deployment in one of the following ways: (a) On the side panel, click on the Actions menu, where you will see an Add Health Checks menu item or (b) Click on the Add Health Checks link on the inline notification in the side panel.

2. In the Add Health Checks form, click on the Add Readiness Probe link. Leave the default values, and click on the check to add the Readiness Probe.

3. Click on the Add Liveness Probe link. Leave the default values, and click on the check to add the Liveness Probe.

4. Click on the Add Startup Probe link. Leave the default values, and click on the check to add the Startup Probe.

5. Click Add when you’re done.

You will be brought back to the Topology View.

Our sample application now has health checks. To ensure that your application is running correctly we will look at our monitoring option.

**Check your work**

To verify there are no health checks configured:

Do you see an inline alert stating that nodejs-sample does not have health checks?


### monitor your sample application.

You should have previously created the sample-app application and nodejs-sample deployment via the Get started with a sample quick start. If you haven't, you may be able to follow these tasks with any existing deployment.

#### Monitoring your sample application

##### To view the details of your sample application:

1. Go to the project your sample application was created in.
    
2. In the </> Developer perspective, go to Topology view.

3. Click on the nodejs-sample deployment to view its details.

4. Click on the Monitoring tab in the side panel.

You can see context sensitive metrics and alerts in the Monitoring tab.

**Check your work**

To verify you can view the monitoring information:

1. Do you see a Metrics accordion in the side panel?
    
2. Do you see a View monitoring dashboard link in the Metrics accordion?

3. Do you see three charts in the Metrics accordion: CPU Usage, Memory Usage and Receive Bandwidth?


#### project monitoring dashboard

##### To view the project monitoring dashboard in the context of nodejs-sample:

1. Click on the View monitoring dashboard link in the side panel.

2. You can change the Time Range and Refresh Interval of the dashboard.

3. You can change the context of the dashboard as well by clicking on the drop-down list. Select a specific workload or All Workloads to view the dashboard in the context of the entire project.

**Check your work**

To verify that you are able to view the monitoring dashboard:

Do you see metrics charts in the dashboard?

#### view custom metrics

##### To view custom metrics:

1. Click on the Metrics tab of the Monitoring page.

2. Click the Select Query drop-down list to see the available queries.

3. Click on Filesystem Usage from the list to run the query.

**Check your work**

Verify you can see the chart associated with the query:

Do you see a chart displayed with filesystem usage for your project? Note: select Custom Query from the dropdown to create and run a custom query utilizing PromQL.

You have learned how to access workload monitoring and metrics!

## OpenShift Console Summary

In this Part you have played with the OpenShift Console and notice what options do you have a developer while working with a rich GUI interface.