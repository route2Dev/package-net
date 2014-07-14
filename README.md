package-net
===========

Extensions for .NET projects package creation

The Package-Net project and resulting nuget package (PackageNet) extends the Package-Web project to non-web applications such as windows services and console applications. 

We have included a sample console application and a sample web application that uses Package-net in the source. You can publish the ExampleConsole application by running the publish.cmd from a command prompt.

Pro tip:
To setup your non-web application to use the Web Deploy pipeline we suggest you look at the following StackOverflow article. 
We found it very helpful in our research. Please note that you will have to manually configure the .pubxml files in your non-web project.

http://stackoverflow.com/questions/18618467/tfs-msbuild-args-pdeployonbuild-true-doesnt-seem-to-do-anything
