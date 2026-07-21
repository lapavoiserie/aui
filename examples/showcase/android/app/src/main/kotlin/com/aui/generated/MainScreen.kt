package com.aui.showcase

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.draw.*

@Composable
fun MainScreen(app: haxe.root.Showcase) {
    var selectedTab by remember { mutableStateOf(0) }

    Scaffold(
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    icon = { Icon(Icons.Filled.List, contentDescription = "Widgets") },
                    label = { Text("Widgets") }
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    icon = { Icon(Icons.Filled.Star, contentDescription = "Modifiers") },
                    label = { Text("Modifiers") }
                )
                NavigationBarItem(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    icon = { Icon(Icons.Filled.Info, contentDescription = "About") },
                    label = { Text("About") }
                )
            }
        }
    ) { innerPadding ->
        when (selectedTab) {
            0 -> {
                Column(modifier = Modifier.padding(innerPadding)) {
                                Column(
                                    modifier = Modifier.padding(16.dp).verticalScroll(rememberScrollState())
                                ) {
                                    Text(
                                        text = "Widgets",
                                        style = MaterialTheme.typography.headlineLarge,
                                        fontWeight = FontWeight.Bold
                                    )
                                    HorizontalDivider()
                                    Text(
                                        text = "Text Input",
                                        style = MaterialTheme.typography.titleMedium,
                                        color = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.padding(vertical = 8.dp)
                                    )
                                    OutlinedTextField(
                                        value = (app.name.get() as String),
                                        onValueChange = { app.name.set(it) },
                                        label = { Text("Enter your name") },
                                        modifier = Modifier.fillMaxWidth()
                                    )
                                    if ((app.darkMode.get() as Boolean)) {
                                        Text(
                                            text = "Hello, ${app.name.get()}!",
                                            color = Color.Blue,
                                            style = MaterialTheme.typography.titleLarge
                                        )
                                    } else {
                                        Text(
                                            text = "Hello, ${app.name.get()}!",
                                            style = MaterialTheme.typography.titleLarge
                                        )
                                    }
                                    HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
                                    Text(
                                        text = "Counter",
                                        style = MaterialTheme.typography.titleMedium,
                                        color = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.padding(vertical = 8.dp)
                                    )
                                    Text(
                                        text = "Count: ${app.count.get()}",
                                        style = MaterialTheme.typography.titleLarge
                                    )
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                                    ) {
                                        Button(
                                            onClick = { app.count.set((app.count.get() as Int) - 1) }
                                        ) {
                                            Text("-")
                                        }
                                        Button(
                                            onClick = { app.count.set(0) }
                                        ) {
                                            Text("Reset")
                                        }
                                        Button(
                                            onClick = { app.count.set((app.count.get() as Int) + 1) }
                                        ) {
                                            Text("+")
                                        }
                                    }
                                    HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
                                    Text(
                                        text = "Toggle",
                                        style = MaterialTheme.typography.titleMedium,
                                        color = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.padding(vertical = 8.dp)
                                    )
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Text(text = "Dark Mode", modifier = Modifier.weight(1f))
                                        Switch(checked = (app.darkMode.get() as Boolean), onCheckedChange = { app.darkMode.set(it) })
                                    }
                                    HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
                                    Text(
                                        text = "Alert",
                                        style = MaterialTheme.typography.titleMedium,
                                        color = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.padding(vertical = 8.dp)
                                    )
                                    if ((app.showAlert.get() as Boolean)) {
                                        AlertDialog(
                                            onDismissRequest = { app.showAlert.set(false) },
                                            title = { Text("Hello!") },
                                            text = { Text("This alert was triggered from Haxe") },
                                            confirmButton = { TextButton(onClick = { app.showAlert.set(false) }) { Text("OK") } }
                                        )
                                    }
                                    Button(
                                        onClick = { app.showAlert.set(!(app.showAlert.get() as Boolean)) }
                                    ) {
                                        Text("Show Alert")
                                    }
                                    HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
                                    Spacer(modifier = Modifier.weight(1f))
                                }
                }
            }
            1 -> {
                Column(modifier = Modifier.padding(innerPadding)) {
                                Column(
                                    modifier = Modifier.padding(16.dp).verticalScroll(rememberScrollState())
                                ) {
                                    Text(
                                        text = "Visual Effects",
                                        style = MaterialTheme.typography.headlineLarge,
                                        fontWeight = FontWeight.Bold
                                    )
                                    HorizontalDivider()
                                    Text(
                                        text = "Shapes & Colors",
                                        style = MaterialTheme.typography.titleMedium,
                                        color = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.padding(vertical = 8.dp)
                                    )
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                                    ) {
                                        Text(
                                            text = "Rounded",
                                            color = Color.White,
                                            modifier = Modifier.padding(12.dp).background(Color.Blue).clip(RoundedCornerShape(8.dp))
                                        )
                                        Text(
                                            text = "Border",
                                            modifier = Modifier.padding(12.dp).border(2.dp, Color.Red).clip(RoundedCornerShape(8.dp))
                                        )
                                        Text(
                                            text = "Shadow",
                                            modifier = Modifier.padding(12.dp).background(Color.White).shadow(elevation = 4.dp)
                                        )
                                    }
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                                    ) {
                                        Text(
                                            text = "50%",
                                            color = Color.White,
                                            modifier = Modifier.padding(12.dp).background(Color(0xFF9C27B0)).alpha(0.5f)
                                        )
                                        Text(
                                            text = "Scaled",
                                            color = Color.White,
                                            modifier = Modifier.padding(12.dp).background(Color.Green).scale(1.2f)
                                        )
                                        Text(
                                            text = "Rotated",
                                            color = Color.White,
                                            modifier = Modifier.padding(12.dp).background(Color(0xFFFF9800)).rotate(15f)
                                        )
                                    }
                                    HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
                                    Text(
                                        text = "Layout",
                                        style = MaterialTheme.typography.titleMedium,
                                        color = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.padding(vertical = 8.dp)
                                    )
                                    Text(
                                        text = "Fill Width",
                                        color = Color.White,
                                        modifier = Modifier.padding(16.dp).background(Color.Gray).fillMaxWidth()
                                    )
                                    Text(
                                        text = "Padded H",
                                        color = Color.White,
                                        modifier = Modifier.padding(horizontal = 32.dp).padding(vertical = 8.dp).background(Color.Blue)
                                    )
                                    HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
                                    Spacer(modifier = Modifier.weight(1f))
                                }
                }
            }
            2 -> {
                Column(modifier = Modifier.padding(innerPadding)) {
                                Column(
                                    modifier = Modifier.padding(16.dp),
                                    horizontalAlignment = Alignment.CenterHorizontally
                                ) {
                                    Spacer(modifier = Modifier.weight(1f))
                                    Text(
                                        text = "AUI Framework",
                                        style = MaterialTheme.typography.headlineLarge,
                                        fontWeight = FontWeight.Bold
                                    )
                                    Text(
                                        text = "v0.1.0",
                                        color = Color.Gray
                                    )
                                    Spacer(modifier = Modifier.weight(1f))
                                    Text(
                                        text = "Write native Android apps in Haxe",
                                        style = MaterialTheme.typography.bodyLarge
                                    )
                                    Text(
                                        text = "Powered by Jetpack Compose",
                                        color = Color.Gray
                                    )
                                    Spacer(modifier = Modifier.weight(1f))
                                    Text(
                                        text = "23 view components",
                                        style = MaterialTheme.typography.titleMedium
                                    )
                                    Text(
                                        text = "30+ modifiers",
                                        style = MaterialTheme.typography.titleMedium
                                    )
                                    Text(
                                        text = "Reactive state management",
                                        style = MaterialTheme.typography.titleMedium
                                    )
                                    Text(
                                        text = "Tab & stack navigation",
                                        style = MaterialTheme.typography.titleMedium
                                    )
                                    Spacer(modifier = Modifier.weight(1f))
                                }
                }
            }
        }
    }
}
