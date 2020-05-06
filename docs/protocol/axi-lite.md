# AXI Lite

<!-- ```wavedrom
{ signal: [
  {    name: 'aclk',   wave: 'p.............'},
  {    name: 'aresetn',   wave: '01............'},
  ['Master',
    ['ctrl',
        {name: 'strb', wave: '0.............'},
        {name: 'keep', wave: '0.............'},
        {name: 'id', wave: '0.............'},
        {name: 'dest', wave: '0.............'},
        {name: 'user', wave: '0.............'},
        {name: 'last', wave: '0......10.....'},
        {name: 'valid', wave: '0..1....0.....'},
    ],
    ['data',
        {  name: 'data',  wave: 'x..3.x.4x.....', data: 'A1 A2'},
    ]
  ],
  {},
  ['Slave',
    ['ctrl',
      {name: 'ready',   wave: '0.1..0.1......'},
    ],
    ['data',
        {  name: 'data',  wave: 'x..3.x.4x.....', data: 'A1 A2'},
    ]
  ]
],
head:{
   text:'AXI Stream Example',
   tick:0,
 },
 foot:{
   text:'Figure 1',
   tock:10
 },
config: { hscale: 1 }
}
``` -->