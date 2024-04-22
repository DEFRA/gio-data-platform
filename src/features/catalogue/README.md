# Introduction
There is a **DEFRA** wide data catalogue used by multiple ALB's across the estate. Microsoft Purview is the technology choice.

## Guidelines
- There should ideally be one Purview Instance Per tenant (Except Ephemeral environments)
- Changes directly in Production **are not Permitted**
- Changes must go through the automated pipelines and quality gates
- You must source control all changes using the extract pipeline

## What is covered by Automation
Currently supported is:
- Collections
- Classifications


# Development lifecycle

In order to successfully make changes in Production you will need to go through the following steps

- Create an ephemeral environment
- Make changes in the ephemeral
- Extract the changes to source control
- Complete the automated pull request
- Deploy changes through a number of environments until production

## Step 1 - Create a work Item
Use Azure DevOps to create the work Item (Note down the number as this is useful later)

## Step 2 - Spin up your ephemeral and grab the output url at the end

Supply the work item Id as mentioned above and [Run the Ephemeral](https://dev.azure.com/defragovuk/DEFRA-Common-Platform-Improvements/_build/results?buildId=512144&view=results)

## Step 3 - Open the ephemeral environment at https://web.purview.com

## Step 4 - Make a change or Add a Collection / Classification

## Step 5 - Run the [Extract Pipeline]()


## Why we need ephemerals 
Ephemerals are essential when you have many developers / data stewards making changes concurrently. The only way to guarantee isolation is to ensure people can work in isolation. Ephemerals ensure
- We can rebuild our estate from source control
- We can reduce manual error
- We can extract only the changes we want
- We can experiment and test in isolation without effecting others work
- Reduce potential pollution from other developers / end users

## Process
![Image](https://github.com/DEFRA/gio-data-platform/blob/main/src/features/catalogue/Purview-Process.png?raw=true)
