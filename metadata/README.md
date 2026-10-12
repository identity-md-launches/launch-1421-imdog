# Official IMDog logo

The permanent metadata image value is:

```text
ipfs://bafybeie5pg3kfdo6fl7dllampv44j2bymf46j554n5ehdmsryl5ejbrdre
```

`logo.png` was downloaded directly from the requester's exact gateway URL:

<https://plum-past-catfish-184.mypinata.cloud/ipfs/bafybeie5pg3kfdo6fl7dllampv44j2bymf46j554n5ehdmsryl5ejbrdre>

The response was HTTP 200, `image/png`. The original file is 1,916,448 bytes,
1254 × 1254 pixels, and has SHA-256:

```text
598a473eb52fa3e075f10b5785564e698d684b7b8cf52ecfa7c57c4657c0d628
```

No image-generation, transcoding, cropping, compression or editing was applied.
The file is an archival copy; the token's `image` remains the permanent IPFS URI.
The checksum records the downloaded file bytes, not the IPFS DAG's root hash.

`IMDog.json` has the same fields and values as the deployed token's
`metadataJSON()`. The Base64 payload of `contractURI()` contains that same JSON.
No address is invented here: the launch operator associates this metadata with
the actual factory-emitted token address and Ethereum chain ID 1 after launch.

Run `python3 tools/check_metadata.py` from the root to validate the archival
image's exact bytes and the metadata fields without network access.
