import toga
from toga.constants import Column
from toga.style import Pack
from novin_intelligence.security import NovinAISecuritySystem, SecurityConfig
from novin_intelligence.crime_intelligence import CrimeContext  # For dummy

class NovinApp(toga.App):
    def startup(self):
        # Main window
        self.main_window = toga.MainWindow(title=self.formal_name)
        
        # UI: Box with button and status label
        box = toga.Box(
            children=[
                toga.Label("Novin AI Security System", style=Pack(font_size=20, padding=10)),
                toga.Button(
                    "Start Security Scan",
                    on_press=self.start_scan,
                    style=Pack(padding=10)
                ),
                toga.Label("Status: Idle", id="status_label", style=Pack(padding=5))
            ],
            style=Pack(
                direction=Column,
                padding=10,
                alignment="center"
            )
        )
        
        self.status_label = self.main_window.content.children[2]  # Hacky ref to label
        self.main_window.content = box
        self.main_window.show()
        
        # Init AI system
        self.system = NovinAISecuritySystem(SecurityConfig())
    
    def start_scan(self, widget):
        try:
            # Dummy request data (simulate motion event)
            dummy_data = {
                "events": [
                    {
                        "type": "motion",
                        "confidence": 0.9,
                        "location": {"latitude": 37.7749, "longitude": -122.4194},
                        "timestamp": "2025-09-27T22:00:00Z"
                    }
                ],
                "timestamp": "2025-09-27T22:00:00Z"
            }
            
            # Process
            result = self.system.process_request(dummy_data, "test_client")
            
            # Update UI
            threat = result.get("threatLevel", "UNKNOWN")
            score = result.get("threatScore", 0)
            self.status_label.text = f"Threat: {threat} (Score: {score:.2f})\nReasoning: {result.get('reasoning', {}).get('assessment', 'N/A')}"
            
            # Log
            print(f"Scan complete: {result}")
            
        except Exception as e:
            self.status_label.text = f"Error: {str(e)}"

def main():
    return NovinApp()
