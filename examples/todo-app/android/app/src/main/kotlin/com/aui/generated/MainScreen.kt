package com.aui.todo

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
fun MainScreen(app: haxe.root.TodoApp) {
    var selectedTab by remember { mutableStateOf(0) }

    Scaffold(
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    icon = { Icon(Icons.Filled.List, contentDescription = "Tasks") },
                    label = { Text("Tasks") }
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    icon = { Icon(Icons.Filled.Edit, contentDescription = "Notes") },
                    label = { Text("Notes") }
                )
                NavigationBarItem(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    icon = { Icon(Icons.Filled.Settings, contentDescription = "Settings") },
                    label = { Text("Settings") }
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
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Column(
                                            horizontalAlignment = Alignment.CenterHorizontally
                                        ) {
                                            Text(
                                                text = "My Tasks",
                                                style = MaterialTheme.typography.headlineLarge,
                                                fontWeight = FontWeight.Bold
                                            )
                                            Text(
                                                text = "Tap to mark as done",
                                                color = Color.Gray,
                                                style = MaterialTheme.typography.bodyMedium
                                            )
                                        }
                                        Spacer(modifier = Modifier.weight(1f))
                                    }
                                    HorizontalDivider()
                                    Text(
                                        text = "Work",
                                        style = MaterialTheme.typography.titleMedium,
                                        color = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.padding(vertical = 8.dp)
                                    )
                                    if ((app.task1Done.get() as Boolean)) {
                                        Card(
                                            modifier = Modifier.alpha(0.5f).fillMaxWidth()
                                        ) {
                                            Row(
                                                modifier = Modifier.padding(12.dp),
                                                verticalAlignment = Alignment.CenterVertically,
                                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                                            ) {
                                                Text(
                                                    text = "  ",
                                                    modifier = Modifier.background(Color.Green).clip(RoundedCornerShape(4.dp)).padding(4.dp)
                                                )
                                                Text(
                                                    text = "Design new landing page",
                                                    color = Color.Gray,
                                                    style = MaterialTheme.typography.bodyLarge
                                                )
                                                Spacer(modifier = Modifier.weight(1f))
                                                Button(
                                                    onClick = { app.task1Done.set(!(app.task1Done.get() as Boolean)) }
                                                ) {
                                                    Text("Undo")
                                                }
                                            }
                                        }
                                    } else {
                                        Card(
                                            modifier = Modifier.fillMaxWidth()
                                        ) {
                                            Row(
                                                modifier = Modifier.padding(12.dp),
                                                verticalAlignment = Alignment.CenterVertically,
                                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                                            ) {
                                                Text(
                                                    text = "  ",
                                                    modifier = Modifier.background(Color.Unspecified).clip(RoundedCornerShape(4.dp)).padding(4.dp)
                                                )
                                                Text(
                                                    text = "Design new landing page",
                                                    style = MaterialTheme.typography.bodyLarge
                                                )
                                                Spacer(modifier = Modifier.weight(1f))
                                                Button(
                                                    onClick = { app.task1Done.set(!(app.task1Done.get() as Boolean)) }
                                                ) {
                                                    Text("Done")
                                                }
                                            }
                                        }
                                    }
                                    if ((app.task2Done.get() as Boolean)) {
                                        Card(
                                            modifier = Modifier.alpha(0.5f).fillMaxWidth()
                                        ) {
                                            Row(
                                                modifier = Modifier.padding(12.dp),
                                                verticalAlignment = Alignment.CenterVertically,
                                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                                            ) {
                                                Text(
                                                    text = "  ",
                                                    modifier = Modifier.background(Color.Green).clip(RoundedCornerShape(4.dp)).padding(4.dp)
                                                )
                                                Text(
                                                    text = "Review pull requests",
                                                    color = Color.Gray,
                                                    style = MaterialTheme.typography.bodyLarge
                                                )
                                                Spacer(modifier = Modifier.weight(1f))
                                                Button(
                                                    onClick = { app.task2Done.set(!(app.task2Done.get() as Boolean)) }
                                                ) {
                                                    Text("Undo")
                                                }
                                            }
                                        }
                                    } else {
                                        Card(
                                            modifier = Modifier.fillMaxWidth()
                                        ) {
                                            Row(
                                                modifier = Modifier.padding(12.dp),
                                                verticalAlignment = Alignment.CenterVertically,
                                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                                            ) {
                                                Text(
                                                    text = "  ",
                                                    modifier = Modifier.background(Color.Unspecified).clip(RoundedCornerShape(4.dp)).padding(4.dp)
                                                )
                                                Text(
                                                    text = "Review pull requests",
                                                    style = MaterialTheme.typography.bodyLarge
                                                )
                                                Spacer(modifier = Modifier.weight(1f))
                                                Button(
                                                    onClick = { app.task2Done.set(!(app.task2Done.get() as Boolean)) }
                                                ) {
                                                    Text("Done")
                                                }
                                            }
                                        }
                                    }
                                    if ((app.task3Done.get() as Boolean)) {
                                        Card(
                                            modifier = Modifier.alpha(0.5f).fillMaxWidth()
                                        ) {
                                            Row(
                                                modifier = Modifier.padding(12.dp),
                                                verticalAlignment = Alignment.CenterVertically,
                                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                                            ) {
                                                Text(
                                                    text = "  ",
                                                    modifier = Modifier.background(Color.Green).clip(RoundedCornerShape(4.dp)).padding(4.dp)
                                                )
                                                Text(
                                                    text = "Update dependencies",
                                                    color = Color.Gray,
                                                    style = MaterialTheme.typography.bodyLarge
                                                )
                                                Spacer(modifier = Modifier.weight(1f))
                                                Button(
                                                    onClick = { app.task3Done.set(!(app.task3Done.get() as Boolean)) }
                                                ) {
                                                    Text("Undo")
                                                }
                                            }
                                        }
                                    } else {
                                        Card(
                                            modifier = Modifier.fillMaxWidth()
                                        ) {
                                            Row(
                                                modifier = Modifier.padding(12.dp),
                                                verticalAlignment = Alignment.CenterVertically,
                                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                                            ) {
                                                Text(
                                                    text = "  ",
                                                    modifier = Modifier.background(Color.Unspecified).clip(RoundedCornerShape(4.dp)).padding(4.dp)
                                                )
                                                Text(
                                                    text = "Update dependencies",
                                                    style = MaterialTheme.typography.bodyLarge
                                                )
                                                Spacer(modifier = Modifier.weight(1f))
                                                Button(
                                                    onClick = { app.task3Done.set(!(app.task3Done.get() as Boolean)) }
                                                ) {
                                                    Text("Done")
                                                }
                                            }
                                        }
                                    }
                                    HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
                                    Text(
                                        text = "Personal",
                                        style = MaterialTheme.typography.titleMedium,
                                        color = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.padding(vertical = 8.dp)
                                    )
                                    if ((app.task4Done.get() as Boolean)) {
                                        Card(
                                            modifier = Modifier.alpha(0.5f).fillMaxWidth()
                                        ) {
                                            Row(
                                                modifier = Modifier.padding(12.dp),
                                                verticalAlignment = Alignment.CenterVertically,
                                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                                            ) {
                                                Text(
                                                    text = "  ",
                                                    modifier = Modifier.background(Color.Green).clip(RoundedCornerShape(4.dp)).padding(4.dp)
                                                )
                                                Text(
                                                    text = "Buy groceries",
                                                    color = Color.Gray,
                                                    style = MaterialTheme.typography.bodyLarge
                                                )
                                                Spacer(modifier = Modifier.weight(1f))
                                                Button(
                                                    onClick = { app.task4Done.set(!(app.task4Done.get() as Boolean)) }
                                                ) {
                                                    Text("Undo")
                                                }
                                            }
                                        }
                                    } else {
                                        Card(
                                            modifier = Modifier.fillMaxWidth()
                                        ) {
                                            Row(
                                                modifier = Modifier.padding(12.dp),
                                                verticalAlignment = Alignment.CenterVertically,
                                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                                            ) {
                                                Text(
                                                    text = "  ",
                                                    modifier = Modifier.background(Color.Unspecified).clip(RoundedCornerShape(4.dp)).padding(4.dp)
                                                )
                                                Text(
                                                    text = "Buy groceries",
                                                    style = MaterialTheme.typography.bodyLarge
                                                )
                                                Spacer(modifier = Modifier.weight(1f))
                                                Button(
                                                    onClick = { app.task4Done.set(!(app.task4Done.get() as Boolean)) }
                                                ) {
                                                    Text("Done")
                                                }
                                            }
                                        }
                                    }
                                    if ((app.task5Done.get() as Boolean)) {
                                        Card(
                                            modifier = Modifier.alpha(0.5f).fillMaxWidth()
                                        ) {
                                            Row(
                                                modifier = Modifier.padding(12.dp),
                                                verticalAlignment = Alignment.CenterVertically,
                                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                                            ) {
                                                Text(
                                                    text = "  ",
                                                    modifier = Modifier.background(Color.Green).clip(RoundedCornerShape(4.dp)).padding(4.dp)
                                                )
                                                Text(
                                                    text = "Go for a run",
                                                    color = Color.Gray,
                                                    style = MaterialTheme.typography.bodyLarge
                                                )
                                                Spacer(modifier = Modifier.weight(1f))
                                                Button(
                                                    onClick = { app.task5Done.set(!(app.task5Done.get() as Boolean)) }
                                                ) {
                                                    Text("Undo")
                                                }
                                            }
                                        }
                                    } else {
                                        Card(
                                            modifier = Modifier.fillMaxWidth()
                                        ) {
                                            Row(
                                                modifier = Modifier.padding(12.dp),
                                                verticalAlignment = Alignment.CenterVertically,
                                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                                            ) {
                                                Text(
                                                    text = "  ",
                                                    modifier = Modifier.background(Color.Unspecified).clip(RoundedCornerShape(4.dp)).padding(4.dp)
                                                )
                                                Text(
                                                    text = "Go for a run",
                                                    style = MaterialTheme.typography.bodyLarge
                                                )
                                                Spacer(modifier = Modifier.weight(1f))
                                                Button(
                                                    onClick = { app.task5Done.set(!(app.task5Done.get() as Boolean)) }
                                                ) {
                                                    Text("Done")
                                                }
                                            }
                                        }
                                    }
                                    if ((app.task6Done.get() as Boolean)) {
                                        Card(
                                            modifier = Modifier.alpha(0.5f).fillMaxWidth()
                                        ) {
                                            Row(
                                                modifier = Modifier.padding(12.dp),
                                                verticalAlignment = Alignment.CenterVertically,
                                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                                            ) {
                                                Text(
                                                    text = "  ",
                                                    modifier = Modifier.background(Color.Green).clip(RoundedCornerShape(4.dp)).padding(4.dp)
                                                )
                                                Text(
                                                    text = "Read a chapter",
                                                    color = Color.Gray,
                                                    style = MaterialTheme.typography.bodyLarge
                                                )
                                                Spacer(modifier = Modifier.weight(1f))
                                                Button(
                                                    onClick = { app.task6Done.set(!(app.task6Done.get() as Boolean)) }
                                                ) {
                                                    Text("Undo")
                                                }
                                            }
                                        }
                                    } else {
                                        Card(
                                            modifier = Modifier.fillMaxWidth()
                                        ) {
                                            Row(
                                                modifier = Modifier.padding(12.dp),
                                                verticalAlignment = Alignment.CenterVertically,
                                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                                            ) {
                                                Text(
                                                    text = "  ",
                                                    modifier = Modifier.background(Color.Unspecified).clip(RoundedCornerShape(4.dp)).padding(4.dp)
                                                )
                                                Text(
                                                    text = "Read a chapter",
                                                    style = MaterialTheme.typography.bodyLarge
                                                )
                                                Spacer(modifier = Modifier.weight(1f))
                                                Button(
                                                    onClick = { app.task6Done.set(!(app.task6Done.get() as Boolean)) }
                                                ) {
                                                    Text("Done")
                                                }
                                            }
                                        }
                                    }
                                    HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
                                }
                }
            }
            1 -> {
                Column(modifier = Modifier.padding(innerPadding)) {
                                Column(
                                    modifier = Modifier.padding(16.dp),
                                    horizontalAlignment = Alignment.CenterHorizontally
                                ) {
                                    Text(
                                        text = "Quick Notes",
                                        style = MaterialTheme.typography.headlineLarge,
                                        fontWeight = FontWeight.Bold
                                    )
                                    Text(
                                        text = "Jot down your thoughts",
                                        color = Color.Gray,
                                        style = MaterialTheme.typography.bodyMedium
                                    )
                                    HorizontalDivider()
                                    Spacer(modifier = Modifier.weight(1f))
                                    OutlinedTextField(
                                        value = (app.noteText.get() as String),
                                        onValueChange = { app.noteText.set(it) },
                                        label = { Text("Write something...") },
                                        modifier = Modifier.fillMaxWidth()
                                    )
                                    Spacer(modifier = Modifier.weight(1f))
                                    Card(
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Text(
                                            text = "${app.noteText.get()}",
                                            style = MaterialTheme.typography.bodyLarge,
                                            modifier = Modifier.padding(16.dp).fillMaxWidth()
                                        )
                                    }
                                    Spacer(modifier = Modifier.weight(1f))
                                    Button(
                                        onClick = { app.noteText.set("") }
                                    ) {
                                        Text("Clear")
                                    }
                                    Spacer(modifier = Modifier.weight(1f))
                                }
                }
            }
            2 -> {
                Column(modifier = Modifier.padding(innerPadding)) {
                                Column(
                                    modifier = Modifier.padding(16.dp).verticalScroll(rememberScrollState())
                                ) {
                                    Text(
                                        text = "Settings",
                                        style = MaterialTheme.typography.headlineLarge,
                                        fontWeight = FontWeight.Bold
                                    )
                                    HorizontalDivider()
                                    Text(
                                        text = "Preferences",
                                        style = MaterialTheme.typography.titleMedium,
                                        color = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.padding(vertical = 8.dp)
                                    )
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Text(text = "Enable notifications", modifier = Modifier.weight(1f))
                                        Switch(checked = (app.notifications.get() as Boolean), onCheckedChange = { app.notifications.set(it) })
                                    }
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Text(text = "Compact mode", modifier = Modifier.weight(1f))
                                        Switch(checked = (app.compactMode.get() as Boolean), onCheckedChange = { app.compactMode.set(it) })
                                    }
                                    HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
                                    Text(
                                        text = "Data",
                                        style = MaterialTheme.typography.titleMedium,
                                        color = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.padding(vertical = 8.dp)
                                    )
                                    if ((app.showConfirm.get() as Boolean)) {
                                        AlertDialog(
                                            onDismissRequest = { app.showConfirm.set(false) },
                                            title = { Text("Reset Tasks") },
                                            text = { Text("This will mark all tasks as not done.") },
                                            confirmButton = { TextButton(onClick = { app.showConfirm.set(false) }) { Text("OK") } }
                                        )
                                    }
                                    Button(
                                        onClick = { app.showConfirm.set(!(app.showConfirm.get() as Boolean)) },
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Text("Reset all tasks")
                                    }
                                    HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
                                    Text(
                                        text = "About",
                                        style = MaterialTheme.typography.titleMedium,
                                        color = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.padding(vertical = 8.dp)
                                    )
                                    Card(
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Column(
                                            modifier = Modifier.padding(16.dp),
                                            horizontalAlignment = Alignment.CenterHorizontally
                                        ) {
                                            Text(
                                                text = "Todo App",
                                                style = MaterialTheme.typography.titleLarge,
                                                fontWeight = FontWeight.Bold
                                            )
                                            Text(
                                                text = "Built with AUI Framework v0.1.0",
                                                color = Color.Gray,
                                                style = MaterialTheme.typography.bodyMedium
                                            )
                                            HorizontalDivider()
                                            Row(
                                                verticalAlignment = Alignment.CenterVertically,
                                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                                            ) {
                                                Text(
                                                    text = "Haxe",
                                                    color = Color.Blue,
                                                    style = MaterialTheme.typography.bodyMedium,
                                                    fontWeight = FontWeight.Bold
                                                )
                                                Text(
                                                    text = "+",
                                                    color = Color.Gray
                                                )
                                                Text(
                                                    text = "Jetpack Compose",
                                                    color = Color.Blue,
                                                    style = MaterialTheme.typography.bodyMedium,
                                                    fontWeight = FontWeight.Bold
                                                )
                                            }
                                            Text(
                                                text = "Material Design 3",
                                                color = Color.Gray,
                                                style = MaterialTheme.typography.bodySmall
                                            )
                                        }
                                    }
                                    HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
                                }
                }
            }
        }
    }
}
