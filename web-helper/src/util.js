export function serialize(objects) {
  return Object.values(objects)
    .filter(Boolean)
    .map((obj) => {
      const { item, chance, more, moreChance } = obj;
      if (item && chance) {
        if (more) {
          let str = `item:${item},chance:${chance}`;
          str += `,more:${more}`;
          if (moreChance > 0) {
            str += `,moreChance:${moreChance}`;
          }
          return str;
        } else {
          return `${item}:${chance}`;
        }
      }
    })
    .filter(Boolean)
    .join(";");
}

export function deserialize(string) {
  var items = {};
  string.split(";").forEach((item, index) => {
    if (!item.trim()) {
      return;
    }
    if (item.indexOf(",") > -1) {
      let myItem = {};
      item.split(",").forEach((itemPart) => {
        const [key, value] = itemPart.split(":");
        myItem[key] = value;
      });
      items[index] = myItem;
      //   items.push(myItem);
    } else {
      const [itemName, chance] = item.split(":");
      items[index] = {
        //   items.push({
        item: itemName,
        chance,
      };
    }
  });
  return items;
}
