# Release steps

## Update ros2.repos file
```
git clone https://github.com/space-ros/space-ros.git
cd space-ros
git checkout -b <release-id>
docker buildx build --target export-repos --output type=local,dest=. .
git add ros2.repos
git commit -m "Update repos file for <release-id> release"
```
