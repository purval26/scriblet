const express = require('express');
const path = require('path');
const app = express();

// Serve static files from the build/web directory
app.use(express.static(path.join(__dirname, 'build/web')));

// Handle all routes by serving index.html
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'build/web/index.html'));
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
