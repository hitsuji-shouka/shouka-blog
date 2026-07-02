#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = path.resolve(import.meta.dirname, "..");
const lockPath = path.join(root, "frontend", "package-lock.json");
const lock = JSON.parse(fs.readFileSync(lockPath, "utf8"));
const packages = lock.packages ?? {};
const missing = [];

for (const [packagePath, packageData] of Object.entries(packages)) {
  if (!packageData || typeof packageData !== "object") {
    continue;
  }

  const declaredDependencies = {
    ...(packageData.dependencies ?? {}),
    ...(packageData.optionalDependencies ?? {}),
  };

  for (const dependencyName of Object.keys(declaredDependencies)) {
    const dependencyPath = `node_modules/${dependencyName}`;
    if (!packages[dependencyPath]) {
      missing.push(`${packagePath || "<root>"} -> ${dependencyName}`);
    }
  }
}

if (missing.length > 0) {
  console.error("Package lock references dependencies without package entries:");
  for (const item of missing) {
    console.error(`- ${item}`);
  }
  process.exit(1);
}

console.log("OK: frontend package-lock dependency entries are complete");
