class_name Globals

enum Stance { Scouting, Walking, Running, Crawling, Prone }

const CELL_SIZE := 32
const UI_SCALE := 4
const PlayersPerTeam := 5

const Max_Vision := 15
const Max_Movement := 500
const Max_Strength := 100
const Max_Stealth := 100

const StanceMods = {
	Stance.Scouting: { "vision" : 0.8, "movement" : 1000, "visibility" : 1 },
	Stance.Walking: { "vision" : 1, "movement" : 1, "visibility" : 1 },
	Stance.Running: { "vision" : 1.3, "movement" : 0.8, "visibility" : 1.3 },
	Stance.Crawling: { "vision" : 2, "movement" : 2, "visibility" : 0.7 },
	Stance.Prone: { "vision" : 5, "movement" : 5, "visibility" : 0.3 }
}

const map_file_password := "this is just a normal password"
