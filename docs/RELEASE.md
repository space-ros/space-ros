# Release steps

## Update ros2.repos file
```
git clone https://github.com/space-ros/space-ros.git
cd space-ros
git checkout -b <release-id>
docker buildx build --no-cache-filter setup --target export-repos --output type=local,dest=. .
git add ros2.repos
git commit -m "Update repos file for <release-id> release"
```

The generated `ros2.repos` includes the overrides in `spaceros.repos` unchanged.
To change the version of an overridden repository, such as `ament_lint`, edit `spaceros.repos`.
