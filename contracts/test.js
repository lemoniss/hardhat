const maxSpeed = {
  car: 300, 
  bike: 60, 
  motorbike: 200, 
  airplane: 1000,
  helicopter: 400, 
  rocket: 8 * 60 * 60
};

const sortable = Object.entries(maxSpeed)
  .sort(([,a],[,b]) => b-a)
  .reduce((r, [k, v]) => ([...r, k]), []);

  

const rank = Object.values(maxSpeed).sort((a,b) => a-b)

rank

