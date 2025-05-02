const express = require("express");
const mongoose = require("mongoose");
const path = require("path");
const cors = require("cors");


const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());
app.use(express.static(__dirname, { index: false }));

// Connect to MongoDB Modify Link Here
mongoose.connect("mongodb+srv://billydeng97:dhyaaaa@petmanagement.fbbuxnk.mongodb.net/?retryWrites=true&w=majority&appName=PetManagement", {
  useNewUrlParser: true,
  useUnifiedTopology: true,
}).then(() => {
  console.log("Successfully connected to MongoDB");
}).catch(err => {
  console.error("❌ Failed to connect to MongoDB:", err);
});

// Define user Schema
const userSchema = new mongoose.Schema({
  username: String,
  password: String,
  pets: [
    {
      pet_id: String,
      name: String,
      age: Number,
      gender: String,
      weight: Number,
      breed: String,
      species: String,
      doctor: String,
      tel: String,
      sos: String,
      location: {
        latitude: String,
        longitude: String,
      },
      health_reports: [
        {
          report_id: String,
          report_name: String,
          raw_text: String,
          timestamp: String,
        },
      ],
      sugg: [
        {
          text: String,
          timestamp: String,
        },
      ],
    },
  ],
  chat: [
    {
      category: String,
      message: String,
      timestamp: String,
    },
  ],
});

const User = mongoose.model("User", userSchema);


app.get("/", (req, res) => {
  res.redirect("/login");
});

// Route to serve the login page
app.get("/login", (req, res) => {
  res.sendFile(path.join(__dirname, "login.html"));
});

// Get statistics (used by SOS page)
app.get("/stats", async (req, res) => {
  try {
    const users = await User.find();
    const totalUsers = users.length;
    let totalPets = 0;
    let totalReports = 0;
    let totalSOS = 0;

    users.forEach(user => {
      const pets = user.pets || [];
      totalPets += pets.length;
      pets.forEach(pet => {
        totalReports += (pet.health_reports || []).length;
        if (pet.sos === "ing") totalSOS += 1;
      });
    });

    res.json({ totalUsers, totalPets, totalReports, totalSOS });
  } catch (error) {
    console.error("Error in /stats:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Get all users (used by chat page)
app.get("/users", async (req, res) => {
  try {
    const users = await User.find({}, { _id: 0, username: 1 });
    res.json(users);
  } catch (error) {
    console.error("Error in /users:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Get user information (including pets and health reports, used by SOS page)
app.get("/user/:username", async (req, res) => {
  const { username } = req.params;
  try {
    const user = await User.findOne({ username }, { _id: 0 });
    if (user) {
      res.json(user);
    } else {
      res.status(404).json({ message: "❌ User not found" });
    }
  } catch (error) {
    console.error("Error in /user/:username:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Update user information (used by SOS page)
app.put("/user/:username", async (req, res) => {
  const { username } = req.params;
  const { password } = req.body;
  console.log(`Received request to update user: username=${username}`);
  try {
    const updateResult = await User.updateOne(
      { username },
      { $set: { password } }
    );
    if (updateResult.matchedCount > 0) {
      console.log("User updated successfully");
      res.json({ message: "User updated successfully" });
    } else {
      console.log("User not found for username:", username);
      res.status(404).json({ message: "❌ User not found" });
    }
  } catch (error) {
    console.error("Error in /user/:username (PUT):", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Delete user (used by SOS page)
app.delete("/user/:username", async (req, res) => {
  const { username } = req.params;
  try {
    const deleteResult = await User.deleteOne({ username });
    if (deleteResult.deletedCount > 0) {
      console.log("User deleted successfully");
      res.json({ message: "User deleted successfully" });
    } else {
      console.log("User not found for username:", username);
      res.status(404).json({ message: "❌ User not found" });
    }
  } catch (error) {
    console.error("Error in /user/:username (DELETE):", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Update pet information (used by SOS page)
app.put("/pet/:username/:petId", async (req, res) => {
  const { username, petId } = req.params;
  const updatedPet = req.body;
  console.log(`Received request to update pet: username=${username}, petId=${petId}`);
  try {
    const updateResult = await User.updateOne(
      { username, "pets.pet_id": petId },
      { $set: { "pets.$": updatedPet } }
    );
    if (updateResult.matchedCount > 0) {
      console.log("Pet updated successfully");
      res.json({ message: "Pet updated successfully" });
    } else {
      console.log("User or pet not found: username=", username, "petId=", petId);
      res.status(404).json({ message: "❌ User or pet not found" });
    }
  } catch (error) {
    console.error("Error in /pet/:username/:petId:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Delete pet (used by SOS page)
app.delete("/pet/:username/:petId", async (req, res) => {
  const { username, petId } = req.params;
  console.log(`Received request to delete pet: username=${username}, petId=${petId}`);
  try {
    const updateResult = await User.updateOne(
      { username },
      { $pull: { pets: { pet_id: petId } } }
    );
    if (updateResult.modifiedCount > 0) {
      console.log("Pet deleted successfully");
      res.json({ message: "Pet deleted successfully" });
    } else {
      console.log("User or pet not found: username=", username, "petId=", petId);
      res.status(404).json({ message: "❌ User or pet not found" });
    }
  } catch (error) {
    console.error("Error in /pet/:username/:petId (DELETE):", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Delete health report (used by SOS page)
app.delete("/report/:username/:petId/:reportId", async (req, res) => {
  const { username, petId, reportId } = req.params;
  console.log(`Received request to delete report: username=${username}, petId=${petId}, reportId=${reportId}`);
  try {
    const updateResult = await User.updateOne(
      { username, "pets.pet_id": petId },
      { $pull: { "pets.$.health_reports": { report_id: reportId } } }
    );
    if (updateResult.modifiedCount > 0) {
      console.log("Health report deleted successfully");
      res.json({ message: "Health report deleted successfully" });
    } else {
      console.log("User, pet, or report not found: username=", username, "petId=", petId, "reportId=", reportId);
      res.status(404).json({ message: "❌ User, pet, or health report not found" });
    }
  } catch (error) {
    console.error("Error in /report/:username/:petId/:reportId:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Trigger SOS (used by SOS page)
app.post("/sos/:username/:petId", async (req, res) => {
  const { username, petId } = req.params;
  const { latitude, longitude } = req.body;
  if (!latitude || !longitude) {
    return res.status(400).json({ message: "❌ Latitude and longitude cannot be empty" });
  }

  console.log(`Received request to trigger SOS: username=${username}, petId=${petId}`);
  try {
    const updateResult = await User.updateOne(
      { username, "pets.pet_id": petId },
      { $set: { "pets.$.sos": "ing", "pets.$.location": { latitude, longitude } } }
    );
    if (updateResult.matchedCount > 0) {
      console.log("SOS triggered successfully");
      res.json({ message: "SOS triggered successfully" });
    } else {
      console.log("User or pet not found: username=", username, "petId=", petId);
      res.status(404).json({ message: "❌ User or pet not found" });
    }
  } catch (error) {
    console.error("Error in /sos/:username/:petId (POST):", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Get SOS history (specific user, used by SOS page)
app.get("/sos/:username", async (req, res) => {
  const { username } = req.params;
  try {
    const user = await User.findOne({ username });
    if (user) {
      const sosHistory = [];
      user.pets.forEach(pet => {
        if (pet.sos === "ing") {
          sosHistory.push({
            petName: pet.name || "Unnamed",
            status: pet.sos,
            location: pet.location || { latitude: "N/A", longitude: "N/A" },
          });
        }
      });
      res.json(sosHistory);
    } else {
      res.status(404).json({ message: "❌ User not found" });
    }
  } catch (error) {
    console.error("Error in /sos/:username:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Get user chat history (used by chat page)
app.get("/getChatHistory/:username", async (req, res) => {
  const { username } = req.params;
  try {
    const user = await User.findOne({ username });
    if (user) {
      res.json({ username: user.username, chatHistory: user.chat || [] });
    } else {
      res.status(404).json({ message: "❌ User not found" });
    }
  } catch (error) {
    console.error("Error in /getChatHistory/:username:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Store worker's chat message (used by chat page)
app.post("/sendMessage", async (req, res) => {
  const { username, message } = req.body;
  if (!username || !message) {
    return res.status(400).json({ message: "❌ Username and message cannot be empty" });
  }

  console.log(`Received request to send message: username=${username}`);
  try {
    const newMessage = {
      category: "worker",
      message: message,
      timestamp: new Date().toISOString(),
    };
    const updateResult = await User.updateOne(
      { username },
      { $push: { chat: newMessage } }
    );
    if (updateResult.matchedCount > 0) {
      console.log("Message sent successfully");
      res.json({ message: "Message sent successfully", chat: newMessage });
    } else {
      console.log("User not found for username:", username);
      res.status(404).json({ message: "❌ User not found" });
    }
  } catch (error) {
    console.error("Error in /sendMessage:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Get all SOS data (including records with sos as "ing" and "completed", with username, used by SOS page)
app.get("/sos", async (req, res) => {
  try {
    const users = await User.find();
    let sosData = [];

    users.forEach(user => {
      const pets = user.pets || [];
      pets.forEach(pet => {
        if (pet.sos === "ing" || pet.sos === "completed") {
          sosData.push({
            username: user.username,
            petId: pet.pet_id,
            petName: pet.name || "Unknown Pet",
            status: pet.sos,
            location: pet.location || { latitude: "N/A", longitude: "N/A" },
            contact: pet.tel || "N/A"
          });
        }
      });
    });

    res.json(sosData);
  } catch (error) {
    console.error("Error in /sos:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Complete SOS (update sos status to "completed", locate using username and petId, used by SOS page)
app.patch("/sos/:username/:petId/complete", async (req, res) => {
  const { username, petId } = req.params;
  console.log(`Received request to complete SOS: username=${username}, petId=${petId}`);
  try {
    const updateResult = await User.updateOne(
      { username, "pets.pet_id": petId },
      { $set: { "pets.$.sos": "completed" } }
    );
    if (updateResult.matchedCount > 0) {
      if (updateResult.modifiedCount > 0) {
        console.log("SOS status updated to completed");
        res.json({ message: "SOS completed" });
      } else {
        console.log("No changes made to SOS status");
        res.json({ message: "SOS completed (status unchanged)" });
      }
    } else {
      console.log("User or pet not found: username=", username, "petId=", petId);
      res.status(404).json({ message: "❌ User or pet not found" });
    }
  } catch (error) {
    console.error("Error in /sos/:username/:petId/complete:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Save doctor's suggestion (add new suggestion)
app.post("/api/sugg/:username", async (req, res) => {
  const { username } = req.params;
  const { suggestion } = req.body;

  if (!suggestion || !suggestion.trim()) {
    return res.status(400).json({ message: "❌ Suggestion cannot be empty" });
  }

  try {
    const user = await User.findOne({ username });
    if (!user || !user.pets || user.pets.length === 0) {
      return res.status(404).json({ message: "❌ User or pet not found" });
    }

    const petId = user.pets[0].pet_id;
    const updateResult = await User.updateOne(
      { username, "pets.pet_id": petId },
      { $push: { "pets.$.sugg": { text: suggestion, timestamp: new Date().toISOString() } } }
    );

    if (updateResult.matchedCount > 0) {
      console.log("Suggestion saved successfully");
      res.json({ message: "Suggestion saved successfully" });
    } else {
      res.status(404).json({ message: "❌ Failed to save suggestion" });
    }
  } catch (error) {
    console.error("Error saving suggestion:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Get doctor's suggestions (get suggestions)
app.get("/api/sugg/:username", async (req, res) => {
  const { username } = req.params;
  try {
    const user = await User.findOne({ username });
    if (!user || !user.pets || user.pets.length === 0) {
      return res.status(404).json({ message: "❌ User or pet not found" });
    }

    const pet = user.pets[0];
    const suggestions = pet.sugg || [];
    res.json({ suggestions });
  } catch (error) {
    console.error("Error fetching suggestions:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`Server running at http://127.0.0.1:${PORT}`);
});