---
title: "{{ replace .Name "-" " " | title }}"
date: {{ .Date }}
draft: false
serves: 0
total_time_to_make: 0
time_to_prepare: 0
time_to_cook: 0
tags:
meal-types:
---

{{% ingredients %}}
- first ingredient
- second ingredient
{{% /ingredients %}}

{{% instructions %}}
- step 1
- step 2
{{% /instructions %}}
