import json, pathlib, urllib.request, re
URL="https://csrc.nist.gov/csrc/media/Projects/cprt/documents/nice/v2-2-0_nf_components.json"
with urllib.request.urlopen(URL,timeout=90) as response:
    data=json.load(response)
assert data["documents"][0]["version"]=="2.2.0"
elements=data["elements"]
roles=[e for e in elements if e["element_type"]=="work_role"]
assert len(roles)==42
ids={e["element_identifier"] for e in elements}
assert len(ids)==len(elements)
assert all(any(re.fullmatch(k+r"\d+",i) for i in ids) for k in "TKS")
assert data["relationships"]
out=pathlib.Path("web/genesis-nice-official.json")
out.write_text(json.dumps(data,ensure_ascii=False,separators=(",",":")),encoding="utf-8")
print("NICE",len(roles),"roles",len(elements),"elements",len(data["relationships"]),"relationships")
