# agentk-edge-tools

Tools for pulling network inventory from a site edge computer and merging the results into a single spreadsheet.

---

# Download edge tool script

```bash
curl -L https://raw.githubusercontent.com/niveek07/agentk-edge-tools/main/edge_site_tool.sh -o edge_site_tool.sh
````

---

# Fix Windows line endings (if script was created on Windows)

```bash
sed -i 's/\r$//' edge_site_tool.sh
```

---

# Make script executable

```bash
chmod +x edge_site_tool.sh
```

---

# Run edge tool script

```bash
./edge_site_tool.sh
```

---

# Download merge script

```bash
curl -L https://raw.githubusercontent.com/niveek07/agentk-edge-tools/main/merge_site_inventory.py -o merge_site_inventory.py
```

---

# Fix Windows line endings for python script

```bash
sed -i 's/\r$//' merge_site_inventory.py
```

---

# Run merge script

```bash
python3 merge_site_inventory.py
```

---

# If you get Windows line ending errors

Common errors when a file was edited on Windows:

```
bad interpreter: /bin/bash^M
$'\r': command not found
```

Fix with:

```bash
sed -i 's/\r$//' edge_site_tool.sh
```

or

```bash
sed -i 's/\r$//' merge_site_inventory.py
```

---

# Typical site workflow

Run these in order on the edge computer terminal.

```bash
curl -L https://raw.githubusercontent.com/niveek07/agentk-edge-tools/main/edge_site_tool.sh -o edge_site_tool.sh
```

```bash
sed -i 's/\r$//' edge_site_tool.sh
```

```bash
chmod +x edge_site_tool.sh
```

```bash
./edge_site_tool.sh
```

```bash
curl -L https://raw.githubusercontent.com/niveek07/agentk-edge-tools/main/merge_site_inventory.py -o merge_site_inventory.py
```

```bash
sed -i 's/\r$//' merge_site_inventory.py
```

```bash
python3 merge_site_inventory.py
```
