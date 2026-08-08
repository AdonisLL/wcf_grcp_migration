#!/usr/bin/env node

import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const defaultRulesPath = join(scriptDirectory, "semantic-digest-rules.v1.json");

function fail(message) {
  console.error(message);
  process.exitCode = 1;
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function decodePointer(pointer) {
  if (!pointer.startsWith("/")) {
    throw new Error(`Invalid JSON Pointer exclusion: ${pointer}`);
  }

  return pointer
    .slice(1)
    .split("/")
    .map((part) => part.replaceAll("~1", "/").replaceAll("~0", "~"));
}

function removeAtPattern(value, segments, index = 0) {
  if (value === null || typeof value !== "object") {
    return;
  }

  const segment = segments[index];
  const keys = segment === "*" ? Object.keys(value) : [segment];
  for (const key of keys) {
    if (!Object.hasOwn(value, key)) {
      continue;
    }

    if (index === segments.length - 1) {
      if (Array.isArray(value)) {
        throw new Error("Array elements cannot be excluded directly; exclude a field within each element.");
      }
      delete value[key];
      continue;
    }

    removeAtPattern(value[key], segments, index + 1);
  }
}

function assertValidUnicode(value, path = "$") {
  if (typeof value === "string") {
    for (let index = 0; index < value.length; index += 1) {
      const code = value.charCodeAt(index);
      if (code >= 0xd800 && code <= 0xdbff) {
        const next = value.charCodeAt(index + 1);
        if (!(next >= 0xdc00 && next <= 0xdfff)) {
          throw new Error(`Unpaired high surrogate at ${path}`);
        }
        index += 1;
      } else if (code >= 0xdc00 && code <= 0xdfff) {
        throw new Error(`Unpaired low surrogate at ${path}`);
      }
    }
    return;
  }

  if (Array.isArray(value)) {
    value.forEach((item, index) => assertValidUnicode(item, `${path}[${index}]`));
    return;
  }

  if (value && typeof value === "object") {
    for (const [key, item] of Object.entries(value)) {
      assertValidUnicode(key, `${path} key`);
      assertValidUnicode(item, `${path}.${key}`);
    }
  }
}

function canonicalize(value) {
  if (value === null || typeof value === "boolean" || typeof value === "string") {
    return JSON.stringify(value);
  }
  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      throw new Error("RFC 8785 does not permit non-finite numbers.");
    }
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return `[${value.map(canonicalize).join(",")}]`;
  }
  if (typeof value === "object") {
    return `{${Object.keys(value)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${canonicalize(value[key])}`)
      .join(",")}}`;
  }
  throw new Error(`Unsupported JSON value type: ${typeof value}`);
}

function prepare(document, rules) {
  const clone = structuredClone(document);
  const artifactType = clone.artifactType ?? (
    typeof clone.id === "string" && clone.id.startsWith("WP-")
      ? "work-package"
      : "default"
  );
  const exclusions = [
    ...rules.globalExclusions,
    ...(rules.artifactExclusions[artifactType] ?? [])
  ];

  for (const pointer of exclusions) {
    removeAtPattern(clone, decodePointer(pointer));
  }
  assertValidUnicode(clone);
  return { clone, artifactType, exclusions };
}

function compute(document, rules) {
  const prepared = prepare(document, rules);
  const canonical = canonicalize(prepared.clone);
  return {
    ...prepared,
    canonical,
    digest: `sha256:${createHash("sha256").update(canonical, "utf8").digest("hex")}`
  };
}

function runSelfTest(fixturePath, rules) {
  const fixture = readJson(fixturePath);
  const numericCanonical = canonicalize(fixture.numericCorpus);
  if (numericCanonical !== fixture.expectedNumericCanonicalJson) {
    throw new Error(
      `RFC 8785 numeric corpus mismatch: expected ${fixture.expectedNumericCanonicalJson}; computed ${numericCanonical}`
    );
  }
  const base = compute(fixture.base, rules).digest;
  const lifecycle = compute(fixture.lifecycleMutation, rules).digest;
  const semantic = compute(fixture.semanticMutation, rules).digest;
  if (base !== lifecycle) {
    throw new Error("Lifecycle-only mutation changed the semantic digest.");
  }
  if (base === semantic) {
    throw new Error("Semantic mutation did not change the semantic digest.");
  }
  console.log(`Self-test passed (${base}).`);
}

const argumentsList = process.argv.slice(2);
const command = argumentsList.shift();
const filePath = argumentsList.shift();
let expectedDigest;
let rulesPath = defaultRulesPath;
while (argumentsList.length > 0) {
  const argument = argumentsList.shift();
  if (argument === "--rules") {
    const suppliedPath = argumentsList.shift();
    if (!suppliedPath) {
      throw new Error("--rules requires a path.");
    }
    rulesPath = suppliedPath;
  } else if (command === "verify" && expectedDigest === undefined) {
    expectedDigest = argument;
  } else {
    throw new Error(`Unexpected argument: ${argument}`);
  }
}

try {
  const rules = readJson(rulesPath);
  if (command === "self-test") {
    runSelfTest(filePath, rules);
  } else if (["compute", "verify", "explain"].includes(command) && filePath) {
    const result = compute(readJson(filePath), rules);
    if (command === "compute") {
      console.log(result.digest);
    } else if (command === "verify") {
      if (result.digest !== expectedDigest) {
        fail(`Digest mismatch: expected ${expectedDigest}; computed ${result.digest}`);
      } else {
        console.log(`Digest verified: ${result.digest}`);
      }
    } else {
      console.log(JSON.stringify({
        algorithmVersion: rules.algorithmVersion,
        artifactType: result.artifactType,
        exclusions: result.exclusions,
        canonicalByteLength: Buffer.byteLength(result.canonical, "utf8"),
        digest: result.digest
      }, null, 2));
    }
  } else {
    fail("Usage: Semantic-Digest.mjs compute|verify|explain <json> [expected] [--rules <json>], or self-test <fixture>");
  }
} catch (error) {
  fail(error instanceof Error ? error.message : String(error));
}
